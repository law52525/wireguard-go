//go:build windows

package main

import (
	"bufio"
	"encoding/hex"
	"fmt"
	"net"
	"os"
	"strconv"
	"strings"
	"time"

	"golang.org/x/sys/windows"
)

const (
	// Default named pipe path for UAPI on Windows
	DefaultNamedPipePath = `\\.\pipe\ProtectedPrefix\Administrators\WireGuard`
)

// namedPipeConn implements net.Conn for Windows named pipes
type namedPipeConn struct {
	file *os.File
}

func (c *namedPipeConn) Read(b []byte) (n int, err error) {
	return c.file.Read(b)
}

func (c *namedPipeConn) Write(b []byte) (n int, err error) {
	return c.file.Write(b)
}

func (c *namedPipeConn) Close() error {
	return c.file.Close()
}

func (c *namedPipeConn) LocalAddr() net.Addr {
	return &namedPipeAddr{name: "local"}
}

func (c *namedPipeConn) RemoteAddr() net.Addr {
	return &namedPipeAddr{name: "remote"}
}

func (c *namedPipeConn) SetDeadline(t time.Time) error {
	return c.file.SetDeadline(t)
}

func (c *namedPipeConn) SetReadDeadline(t time.Time) error {
	return c.file.SetReadDeadline(t)
}

func (c *namedPipeConn) SetWriteDeadline(t time.Time) error {
	return c.file.SetWriteDeadline(t)
}

// namedPipeAddr implements net.Addr for named pipes
type namedPipeAddr struct {
	name string
}

func (a *namedPipeAddr) Network() string {
	return "npipe"
}

func (a *namedPipeAddr) String() string {
	return a.name
}

// Discover all WireGuard interfaces on Windows
func discoverInterfaces() ([]string, error) {
	// On Windows, we can't easily enumerate named pipes from Go
	// This is a simplified implementation that returns common interface names
	// In practice, you might want to use Windows API to enumerate named pipes
	commonInterfaces := []string{"wg0", "wg1", "wg2", "utun0", "utun1", "utun2"}

	// For now, we'll assume all common interfaces exist
	// This is a workaround for the npipe network type issue in Go's standard library
	// In a real implementation, you'd want to use proper Windows API to check named pipes

	// Return all common interfaces as a workaround
	// This will allow the tool to work even though we can't properly detect interfaces
	return commonInterfaces, nil
}

// Connect to UAPI socket for the given interface
func connectToInterface(interfaceName string) (net.Conn, error) {
	// Construct named pipe path - use the same path as wireguard-go.exe
	pipePath := fmt.Sprintf(`%s\%s`, DefaultNamedPipePath, interfaceName)

	// Use Windows API to create named pipe connection
	handle, err := windows.CreateFile(
		windows.StringToUTF16Ptr(pipePath),
		windows.GENERIC_READ|windows.GENERIC_WRITE,
		0,
		nil,
		windows.OPEN_EXISTING,
		windows.FILE_ATTRIBUTE_NORMAL,
		0,
	)
	if err != nil {
		if err == windows.ERROR_FILE_NOT_FOUND {
			return nil, fmt.Errorf("interface '%s' not found (named pipe %s does not exist)", interfaceName, pipePath)
		}
		if err == windows.ERROR_ACCESS_DENIED {
			return nil, fmt.Errorf("access denied to interface '%s'\n💡 Try running as administrator", interfaceName)
		}
		return nil, fmt.Errorf("failed to connect to interface '%s': %v", interfaceName, err)
	}

	// Create a file from the handle
	file := os.NewFile(uintptr(handle), pipePath)
	if file == nil {
		windows.CloseHandle(handle)
		return nil, fmt.Errorf("failed to create file from handle for interface '%s'", interfaceName)
	}

	// Create a connection from the file
	conn := &namedPipeConn{file: file}
	return conn, nil
}

// Send UAPI command and read response
func sendUAPICommand(conn net.Conn, command string) (string, error) {
	// Set read timeout
	conn.SetReadDeadline(time.Now().Add(10 * time.Second))
	defer conn.SetReadDeadline(time.Time{}) // Clear timeout

	// Send command with proper formatting
	if command == "get=1" {
		// UAPI get command needs an extra newline
		_, err := fmt.Fprintf(conn, "%s\n\n", command)
		if err != nil {
			return "", fmt.Errorf("failed to send command: %v", err)
		}
	} else {
		_, err := fmt.Fprintf(conn, "%s\n", command)
		if err != nil {
			return "", fmt.Errorf("failed to send command: %v", err)
		}
	}

	// Read response
	var response strings.Builder
	scanner := bufio.NewScanner(conn)

	for scanner.Scan() {
		line := scanner.Text()

		// Check for error response
		if strings.HasPrefix(line, "errno=") {
			errno := strings.TrimPrefix(line, "errno=")
			if errno != "0" {
				return "", fmt.Errorf("UAPI error: errno=%s", errno)
			}
			// After errno, expect another newline then we're done
			if scanner.Scan() && scanner.Text() == "" {
				break
			}
			break
		}

		// Empty line indicates end of response data (before errno)
		if line == "" {
			// Continue to read until we get errno
			continue
		}

		response.WriteString(line)
		response.WriteString("\n")
	}

	if err := scanner.Err(); err != nil {
		return "", fmt.Errorf("failed to read response: %v", err)
	}

	return response.String(), nil
}

// Get interface information via UAPI
func getInterfaceInfo(interfaceName string) (*InterfaceInfo, error) {
	conn, err := connectToInterface(interfaceName)
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	// Send get command
	response, err := sendUAPICommand(conn, "get=1")
	if err != nil {
		return nil, err
	}

	// Parse response
	info := &InterfaceInfo{
		Name:  interfaceName,
		Peers: []PeerInfo{},
	}

	var currentPeer *PeerInfo

	lines := strings.Split(strings.TrimSpace(response), "\n")
	for _, line := range lines {
		if line == "" {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}

		key, value := parts[0], parts[1]

		switch key {
		case "private_key":
			info.PrivateKey = value
		case "public_key":
			// This starts a new peer
			peer := PeerInfo{
				PublicKey:  value,
				AllowedIPs: []string{},
			}
			info.Peers = append(info.Peers, peer)
			currentPeer = &info.Peers[len(info.Peers)-1]
		case "listen_port":
			if port, err := strconv.Atoi(value); err == nil {
				info.ListenPort = port
			}
		case "fwmark":
			if mark, err := strconv.Atoi(value); err == nil {
				info.FwMark = mark
			}
		case "preshared_key":
			if currentPeer != nil {
				currentPeer.PresharedKey = value
			}
		case "endpoint":
			if currentPeer != nil {
				currentPeer.Endpoint = value
			}
		case "last_handshake_time_sec":
			if currentPeer != nil {
				if sec, err := strconv.ParseInt(value, 10, 64); err == nil {
					currentPeer.LastHandshakeTimeSec = sec
				}
			}
		case "last_handshake_time_nsec":
			if currentPeer != nil {
				if nsec, err := strconv.ParseInt(value, 10, 64); err == nil {
					currentPeer.LastHandshakeTimeNsec = nsec
				}
			}
		case "tx_bytes":
			if currentPeer != nil {
				if bytes, err := strconv.ParseInt(value, 10, 64); err == nil {
					currentPeer.TxBytes = bytes
				}
			}
		case "rx_bytes":
			if currentPeer != nil {
				if bytes, err := strconv.ParseInt(value, 10, 64); err == nil {
					currentPeer.RxBytes = bytes
				}
			}
		case "persistent_keepalive_interval":
			if currentPeer != nil {
				if interval, err := strconv.Atoi(value); err == nil {
					currentPeer.PersistentKeepaliveInterval = interval
				}
			}
		case "allowed_ip":
			if currentPeer != nil {
				currentPeer.AllowedIPs = append(currentPeer.AllowedIPs, value)
			}
		}
	}

	// Calculate public key from private key if available
	if info.PrivateKey != "" && info.PrivateKey != "(none)" {
		if privateKey, err := parsePrivateKey(info.PrivateKey); err == nil {
			publicKey := privateKey.PublicKey()
			info.PublicKey = publicKey.String()
		}
	}

	return info, nil
}

// Set configuration via UAPI
func setInterfaceConfig(interfaceName string, config *Config) error {
	conn, err := connectToInterface(interfaceName)
	if err != nil {
		return err
	}
	defer conn.Close()

	// Build UAPI configuration string
	var configStr strings.Builder

	// Interface configuration
	if config.Interface.PrivateKey != "" {
		// Convert base64 private key to hex for UAPI
		if privateKey, err := parsePrivateKey(config.Interface.PrivateKey); err == nil {
			configStr.WriteString(fmt.Sprintf("private_key=%s\n", privateKey.Hex()))
		} else {
			return fmt.Errorf("invalid private key: %v", err)
		}
	}

	if config.Interface.ListenPort >= 0 {
		configStr.WriteString(fmt.Sprintf("listen_port=%d\n", config.Interface.ListenPort))
	}

	// Peer configurations
	for _, peer := range config.Peers {
		// Convert base64 public key to hex for UAPI
		if publicKey, err := parsePublicKey(peer.PublicKey); err == nil {
			configStr.WriteString(fmt.Sprintf("public_key=%s\n", publicKey.Hex()))
		} else {
			return fmt.Errorf("invalid public key: %v", err)
		}

		if peer.PresharedKey != "" {
			// Convert base64 preshared key to hex for UAPI
			if presharedKey, err := parsePresharedKey(peer.PresharedKey); err == nil {
				configStr.WriteString(fmt.Sprintf("preshared_key=%s\n", hex.EncodeToString(presharedKey[:])))
			} else {
				return fmt.Errorf("invalid preshared key: %v", err)
			}
		}

		if peer.Endpoint != "" {
			// Check if endpoint is a domain name
			host, _, err := net.SplitHostPort(peer.Endpoint)
			if err == nil && net.ParseIP(host) == nil {
				// This is a domain name - send original endpoint for DNS monitoring
				fmt.Printf("🔍 Domain endpoint detected: %s (will be monitored for IP changes)\n", peer.Endpoint)
				configStr.WriteString(fmt.Sprintf("endpoint=%s\n", peer.Endpoint))
			} else {
				// This is an IP address or invalid format - resolve it for compatibility
				resolvedEndpoint, err := resolveEndpoint(peer.Endpoint)
				if err != nil {
					fmt.Printf("⚠️  Warning: Failed to resolve endpoint %s: %v\n", peer.Endpoint, err)
					fmt.Printf("   Trying to use original endpoint anyway...\n")
					resolvedEndpoint = peer.Endpoint
				} else {
					fmt.Printf("✅ Resolved %s -> %s\n", peer.Endpoint, resolvedEndpoint)
				}
				configStr.WriteString(fmt.Sprintf("endpoint=%s\n", resolvedEndpoint))
			}
		}

		if peer.PersistentKeepalive > 0 {
			configStr.WriteString(fmt.Sprintf("persistent_keepalive_interval=%d\n", peer.PersistentKeepalive))
		}

		// Clear existing allowed IPs first
		configStr.WriteString("replace_allowed_ips=true\n")

		// Add allowed IPs
		for _, allowedIP := range peer.AllowedIPs {
			configStr.WriteString(fmt.Sprintf("allowed_ip=%s\n", allowedIP))
		}
	}

	// Debug: print what we're sending
	uapiConfig := configStr.String()
	fmt.Printf("🔍 Sending UAPI configuration:\n%s\n", uapiConfig)

	// Send set command
	_, err = fmt.Fprintf(conn, "set=1\n%s\n", uapiConfig)
	if err != nil {
		return fmt.Errorf("failed to send configuration: %v", err)
	}

	// Read response
	scanner := bufio.NewScanner(conn)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "errno=") {
			errno := strings.TrimPrefix(line, "errno=")
			if errno != "0" {
				return fmt.Errorf("UAPI configuration error: errno=%s", errno)
			}
			break
		}
	}

	return scanner.Err()
}

// Resolve domain names in endpoints to IP addresses
func resolveEndpoint(endpoint string) (string, error) {
	// Check if endpoint contains a domain name that needs resolving
	host, port, err := net.SplitHostPort(endpoint)
	if err != nil {
		return endpoint, fmt.Errorf("invalid endpoint format: %v", err)
	}

	// Check if host is already an IP address
	if ip := net.ParseIP(host); ip != nil {
		// Already an IP address, no need to resolve
		return endpoint, nil
	}

	// Resolve domain name to IP address
	fmt.Printf("🔍 Resolving domain: %s\n", host)

	// Use LookupHost for better control over resolution
	ips, err := net.LookupHost(host)
	if err != nil {
		return endpoint, fmt.Errorf("DNS resolution failed: %v", err)
	}

	if len(ips) == 0 {
		return endpoint, fmt.Errorf("no IP addresses found for domain %s", host)
	}

	// Use the first IP address (prefer IPv4 if available)
	var selectedIP string
	for _, ip := range ips {
		if net.ParseIP(ip).To4() != nil {
			// IPv4 address found, prefer it
			selectedIP = ip
			break
		}
	}

	if selectedIP == "" {
		// No IPv4 found, use the first available IP
		selectedIP = ips[0]
	}

	resolvedEndpoint := net.JoinHostPort(selectedIP, port)
	fmt.Printf("✅ Resolved %s -> %s\n", endpoint, resolvedEndpoint)

	return resolvedEndpoint, nil
}

// Print interface information in a nice format
func printInterfaceInfo(info *InterfaceInfo, showPrivateKey bool) {
	fmt.Printf("interface: %s\n", info.Name)

	if info.PublicKey != "" {
		fmt.Printf("  public key: %s\n", info.PublicKey)
	}

	if showPrivateKey && info.PrivateKey != "" && info.PrivateKey != "(none)" {
		fmt.Printf("  private key: %s\n", info.PrivateKey)
	} else {
		fmt.Printf("  private key: (hidden)\n")
	}

	if info.ListenPort > 0 {
		fmt.Printf("  listening port: %d\n", info.ListenPort)
	}

	if info.FwMark > 0 {
		fmt.Printf("  fwmark: 0x%x\n", info.FwMark)
	}

	for i, peer := range info.Peers {
		if i > 0 {
			fmt.Println()
		}
		fmt.Printf("\npeer: %s\n", peer.PublicKey)

		if peer.PresharedKey != "" && peer.PresharedKey != "(none)" {
			fmt.Printf("  preshared key: (hidden)\n")
		}

		if peer.Endpoint != "" {
			fmt.Printf("  endpoint: %s\n", peer.Endpoint)
		}

		if len(peer.AllowedIPs) > 0 {
			fmt.Printf("  allowed ips: %s\n", strings.Join(peer.AllowedIPs, ", "))
		}

		lastHandshake := peer.LastHandshakeTime()
		if !lastHandshake.IsZero() {
			fmt.Printf("  latest handshake: %s\n", lastHandshake.Format("2006-01-02 15:04:05"))
		}

		if peer.TxBytes > 0 || peer.RxBytes > 0 {
			fmt.Printf("  transfer: %s received, %s sent\n",
				formatBytes(peer.RxBytes), formatBytes(peer.TxBytes))
		}

		if peer.PersistentKeepaliveInterval > 0 {
			fmt.Printf("  persistent keepalive: every %d seconds\n", peer.PersistentKeepaliveInterval)
		}
	}

	fmt.Println()
}
