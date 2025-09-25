/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2017-2025 WireGuard LLC. All Rights Reserved.
 */

package device

import (
	"context"
	"net"
	"sync"
	"time"
)

// DNSMonitor manages dynamic DNS resolution for domain-based endpoints
// Automatically updates peer endpoints when IP addresses change
type DNSMonitor struct {
	device   *Device
	peers    map[NoisePublicKey]*monitoredPeer // Map of public key to monitored peer info
	mu       sync.RWMutex                      // Protects peers map and interval
	stopCh   chan struct{}                     // Channel to stop monitoring
	interval time.Duration                     // How often to check DNS resolution
	logger   *Logger                           // Logger for DNS monitor events
}

// monitoredPeer stores information about a peer with a domain-based endpoint
type monitoredPeer struct {
	publicKey       NoisePublicKey // Peer's public key
	originalHost    string         // Original domain name (e.g., "example.com")
	port            string         // Port number as string
	lastResolvedIP  string         // Last successfully resolved IP address
	lastCheckTime   time.Time      // Last time we checked DNS resolution
	resolutionFails int            // Number of consecutive DNS resolution failures
}

// NewDNSMonitor creates a new DNS monitor for the given device
func NewDNSMonitor(device *Device, interval time.Duration) *DNSMonitor {
	if interval <= 0 {
		interval = 60 * time.Second // Default to 60 seconds
	}

	return &DNSMonitor{
		device:   device,
		peers:    make(map[NoisePublicKey]*monitoredPeer),
		stopCh:   make(chan struct{}),
		interval: interval,
		logger:   device.log,
	}
}

// Start begins DNS monitoring in a background goroutine
func (dm *DNSMonitor) Start() {
	dm.logger.Verbosef("DNS Monitor: Starting with %v interval", dm.interval)
	go dm.monitorLoop()
}

// Stop terminates DNS monitoring
func (dm *DNSMonitor) Stop() {
	dm.logger.Verbosef("DNS Monitor: Stopping")
	close(dm.stopCh)
}

// AddPeer adds a peer with a domain-based endpoint to be monitored
func (dm *DNSMonitor) AddPeer(publicKey NoisePublicKey, endpoint string) error {
	host, port, err := net.SplitHostPort(endpoint)
	if err != nil {
		return err
	}

	// Check if the host is a domain name (not an IP address)
	if ip := net.ParseIP(host); ip != nil {
		// This is already an IP address, no need to monitor
		return nil
	}

	// Resolve the domain to get initial IP
	initialIP, err := dm.resolveDomain(host)
	if err != nil {
		dm.logger.Verbosef("DNS Monitor: Failed to resolve initial IP for %s: %v", host, err)
		// Still add to monitoring list in case DNS becomes available later
		initialIP = ""
	}

	dm.mu.Lock()
	defer dm.mu.Unlock()

	dm.peers[publicKey] = &monitoredPeer{
		publicKey:       publicKey,
		originalHost:    host,
		port:            port,
		lastResolvedIP:  initialIP,
		lastCheckTime:   time.Now(),
		resolutionFails: 0,
	}

	dm.logger.Verbosef("DNS Monitor: Added peer %s with domain %s (resolved to %s)",
		publicKey.Hex()[:8], host, initialIP)
	return nil
}

// RemovePeer removes a peer from DNS monitoring
func (dm *DNSMonitor) RemovePeer(publicKey NoisePublicKey) {
	dm.mu.Lock()
	defer dm.mu.Unlock()

	if monPeer, exists := dm.peers[publicKey]; exists {
		delete(dm.peers, publicKey)
		dm.logger.Verbosef("DNS Monitor: Removed peer %s (domain: %s)",
			publicKey.Hex()[:8], monPeer.originalHost)
	}
}

// UpdateMonitorInterval changes the DNS monitoring interval
func (dm *DNSMonitor) UpdateMonitorInterval(interval time.Duration) {
	if interval <= 0 {
		return
	}
	dm.mu.Lock()
	dm.interval = interval
	dm.mu.Unlock()
	dm.logger.Verbosef("DNS Monitor: Updated interval to %v", interval)
}

// GetMonitorInterval returns the current DNS monitoring interval
func (dm *DNSMonitor) GetMonitorInterval() time.Duration {
	dm.mu.RLock()
	defer dm.mu.RUnlock()
	return dm.interval
}

// monitorLoop is the main monitoring loop that runs in a background goroutine
func (dm *DNSMonitor) monitorLoop() {
	ticker := time.NewTicker(dm.interval)
	defer ticker.Stop()

	for {
		select {
		case <-dm.stopCh:
			dm.logger.Verbosef("DNS Monitor: Monitor loop stopped")
			return

		case <-ticker.C:
			dm.checkAllPeers()
		}
	}
}

// checkAllPeers checks DNS resolution for all monitored peers
func (dm *DNSMonitor) checkAllPeers() {
	dm.mu.RLock()
	peers := make(map[NoisePublicKey]*monitoredPeer)
	for k, v := range dm.peers {
		peers[k] = v
	}
	dm.mu.RUnlock()

	if len(peers) == 0 {
		return // No peers to monitor
	}

	dm.logger.Verbosef("DNS Monitor: Checking %d monitored peer(s)", len(peers))

	for publicKey, monPeer := range peers {
		dm.checkPeerDNS(publicKey, monPeer)
	}
}

// checkPeerDNS checks DNS resolution for a single peer and updates endpoint if changed
func (dm *DNSMonitor) checkPeerDNS(publicKey NoisePublicKey, monPeer *monitoredPeer) {
	currentIP, err := dm.resolveDomain(monPeer.originalHost)

	dm.mu.Lock()
	monPeer.lastCheckTime = time.Now()
	dm.mu.Unlock()

	if err != nil {
		dm.mu.Lock()
		monPeer.resolutionFails++
		dm.mu.Unlock()

		dm.logger.Verbosef("DNS Monitor: Failed to resolve %s for peer %s (failure #%d): %v",
			monPeer.originalHost, publicKey.Hex()[:8], monPeer.resolutionFails, err)

		// If we've had too many consecutive failures, log a warning
		if monPeer.resolutionFails == 5 {
			dm.logger.Verbosef("DNS Monitor: Warning - Domain %s has failed resolution 5 times",
				monPeer.originalHost)
		}
		return
	}

	// Reset failure count on successful resolution
	dm.mu.Lock()
	monPeer.resolutionFails = 0
	dm.mu.Unlock()

	// Check if the IP address has changed
	if currentIP != monPeer.lastResolvedIP && monPeer.lastResolvedIP != "" {
		dm.logger.Verbosef("DNS Monitor: IP change detected for %s: %s -> %s",
			monPeer.originalHost, monPeer.lastResolvedIP, currentIP)

		// Update the peer's endpoint
		err := dm.updatePeerEndpoint(publicKey, currentIP, monPeer.port)
		if err != nil {
			dm.logger.Verbosef("DNS Monitor: Failed to update endpoint for peer %s: %v",
				publicKey.Hex()[:8], err)
			return
		}

		dm.logger.Verbosef("DNS Monitor: Successfully updated endpoint for peer %s to %s:%s",
			publicKey.Hex()[:8], currentIP, monPeer.port)
	}

	// Update the stored IP address
	dm.mu.Lock()
	monPeer.lastResolvedIP = currentIP
	dm.mu.Unlock()
}

// resolveDomain resolves a domain name to an IP address (preferring IPv4)
func (dm *DNSMonitor) resolveDomain(domain string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Use LookupHost for better control over resolution
	ips, err := net.DefaultResolver.LookupHost(ctx, domain)
	if err != nil {
		return "", err
	}

	if len(ips) == 0 {
		return "", &net.DNSError{
			Err:        "no IP addresses found",
			Name:       domain,
			IsNotFound: true,
		}
	}

	// Prefer IPv4 addresses
	for _, ip := range ips {
		if net.ParseIP(ip).To4() != nil {
			return ip, nil
		}
	}

	// If no IPv4 found, use the first available IP
	return ips[0], nil
}

// updatePeerEndpoint updates a peer's endpoint with the new IP address
func (dm *DNSMonitor) updatePeerEndpoint(publicKey NoisePublicKey, newIP, port string) error {
	// Look up the peer
	peer := dm.device.LookupPeer(publicKey)
	if peer == nil {
		return &net.DNSError{
			Err:  "peer not found",
			Name: publicKey.Hex(),
		}
	}

	// Construct the new endpoint
	newEndpoint := net.JoinHostPort(newIP, port)

	// Parse the endpoint using the device's bind
	endpoint, err := dm.device.net.bind.ParseEndpoint(newEndpoint)
	if err != nil {
		return err
	}

	// Update the peer's endpoint
	peer.endpoint.Lock()
	defer peer.endpoint.Unlock()

	// Clear the old endpoint source to force reconnection
	if peer.endpoint.val != nil {
		peer.endpoint.clearSrcOnTx = true
	}

	peer.endpoint.val = endpoint

	// Trigger a new handshake to establish connection with the new endpoint
	peer.SendHandshakeInitiation(false)

	return nil
}

// GetMonitoredPeers returns information about currently monitored peers
func (dm *DNSMonitor) GetMonitoredPeers() map[NoisePublicKey]*MonitoredPeerInfo {
	dm.mu.RLock()
	defer dm.mu.RUnlock()

	result := make(map[NoisePublicKey]*MonitoredPeerInfo)
	for publicKey, monPeer := range dm.peers {
		result[publicKey] = &MonitoredPeerInfo{
			OriginalHost:    monPeer.originalHost,
			Port:            monPeer.port,
			LastResolvedIP:  monPeer.lastResolvedIP,
			LastCheckTime:   monPeer.lastCheckTime,
			ResolutionFails: monPeer.resolutionFails,
		}
	}
	return result
}

// MonitoredPeerInfo contains information about a monitored peer (for external access)
type MonitoredPeerInfo struct {
	OriginalHost    string    // Original domain name
	Port            string    // Port number
	LastResolvedIP  string    // Last resolved IP address
	LastCheckTime   time.Time // Last DNS check time
	ResolutionFails int       // Number of consecutive DNS failures
}

// IsDomainEndpoint checks if an endpoint string contains a domain name
func IsDomainEndpoint(endpoint string) bool {
	host, _, err := net.SplitHostPort(endpoint)
	if err != nil {
		return false
	}

	// If it parses as an IP address, it's not a domain
	return net.ParseIP(host) == nil
}

// ExtractDomainFromEndpoint extracts the domain name from an endpoint string
func ExtractDomainFromEndpoint(endpoint string) (string, error) {
	host, _, err := net.SplitHostPort(endpoint)
	if err != nil {
		return "", err
	}

	// Verify it's actually a domain (not an IP)
	if net.ParseIP(host) != nil {
		return "", &net.DNSError{
			Err:  "endpoint contains IP address, not domain",
			Name: host,
		}
	}

	return host, nil
}
