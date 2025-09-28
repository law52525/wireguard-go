package main

import (
	"fmt"
	"time"
)

const (
	// Default socket directory for UAPI on Unix systems
	DefaultSocketDir = "/var/run/wireguard"
)

// InterfaceInfo contains information about a WireGuard interface
type InterfaceInfo struct {
	Name       string
	PrivateKey string
	PublicKey  string
	ListenPort int
	FwMark     int
	Peers      []PeerInfo
}

// PeerInfo contains information about a peer
type PeerInfo struct {
	PublicKey                   string
	PresharedKey                string
	Endpoint                    string
	LastHandshakeTimeSec        int64
	LastHandshakeTimeNsec       int64
	AllowedIPs                  []string
	TxBytes                     int64
	RxBytes                     int64
	PersistentKeepaliveInterval int
}

// Get formatted last handshake time
func (p PeerInfo) LastHandshakeTime() time.Time {
	if p.LastHandshakeTimeSec == 0 {
		return time.Time{}
	}
	return time.Unix(p.LastHandshakeTimeSec, p.LastHandshakeTimeNsec)
}

// Format bytes in human readable format
func formatBytes(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %ciB", float64(bytes)/float64(div), "KMGTPE"[exp])
}
