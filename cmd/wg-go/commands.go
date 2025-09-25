package main

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"os"
	"strconv"
	"strings"
)

// Handle 'genkey' command - generate a new private key
func handleGenkey() {
	key, err := generatePrivateKey()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error generating private key: %v\n", err)
		os.Exit(1)
	}

	fmt.Println(key.String())
}

// Handle 'pubkey' command - calculate public key from private key
func handlePubkey(args []string) {
	var input io.Reader = os.Stdin

	// If a file is specified, read from it
	if len(args) > 0 {
		file, err := os.Open(args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error opening file: %v\n", err)
			os.Exit(1)
		}
		defer file.Close()
		input = file
	}

	// Read private key from input
	scanner := bufio.NewScanner(input)
	if !scanner.Scan() {
		fmt.Fprintf(os.Stderr, "Error reading private key\n")
		os.Exit(1)
	}

	privateKeyStr := strings.TrimSpace(scanner.Text())
	if privateKeyStr == "" {
		fmt.Fprintf(os.Stderr, "Empty private key\n")
		os.Exit(1)
	}

	// Parse private key
	privateKey, err := parsePrivateKey(privateKeyStr)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing private key: %v\n", err)
		os.Exit(1)
	}

	// Calculate and output public key
	publicKey := privateKey.PublicKey()
	fmt.Println(publicKey.String())
}

// Handle 'genpsk' command - generate a new preshared key
func handleGenpsk() {
	key, err := generatePresharedKey()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error generating preshared key: %v\n", err)
		os.Exit(1)
	}

	fmt.Println(key.String())
}

// Handle 'show' command - show WireGuard interface status
func handleShow(args []string) {
	// Check if we need to provide helpful guidance
	if !checkWireGuardAccess() {
		return
	}

	if len(args) == 0 {
		// Show all interfaces
		showAllInterfaces()
	} else {
		// Show specific interface
		interfaceName := args[0]
		showInterface(interfaceName)
	}
}

// Check if we can access WireGuard interfaces and provide helpful guidance
func checkWireGuardAccess() bool {
	// Check if WireGuard directory exists
	socketDir := "/var/run/wireguard"
	if _, err := os.Stat(socketDir); os.IsNotExist(err) {
		fmt.Printf("🚫 WireGuard directory not found: %s\n", socketDir)
		fmt.Println("💡 This usually means no WireGuard interfaces are running.")
		fmt.Println("   To start an interface: sudo ./wireguard-go utun")
		return false
	}

	// Try to list the directory
	entries, err := os.ReadDir(socketDir)
	if err != nil {
		fmt.Printf("❌ Cannot access WireGuard directory: %v\n", err)
		fmt.Println("💡 Try running with sudo: sudo ./cmd/wg-go/wg-go show")
		return false
	}

	// Check if there are any interfaces
	socketCount := 0
	for _, entry := range entries {
		if strings.HasSuffix(entry.Name(), ".sock") {
			socketCount++
		}
	}

	if socketCount == 0 {
		fmt.Println("📭 No WireGuard interfaces found.")
		fmt.Println("💡 To create an interface: sudo ./wireguard-go utun")
		return false
	}

	return true
}

// Handle 'set' command - set WireGuard configuration
func handleSet(args []string) {
	if len(args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: wg-go set <interface> <configuration>\n")
		os.Exit(1)
	}

	interfaceName := args[0]
	fmt.Printf("Setting configuration for interface %s...\n", interfaceName)
	fmt.Println("Note: This is a demonstration. Real implementation would use UAPI.")

	// Parse configuration arguments
	for i := 1; i < len(args); i++ {
		fmt.Printf("  %s\n", args[i])
	}
}

// Handle 'setconf' command - set configuration from file
func handleSetconf(args []string) {
	if len(args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: wg-go setconf <interface> <config-file>\n")
		os.Exit(1)
	}

	interfaceName := args[0]
	configFile := args[1]

	config, err := parseConfigFile(configFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing config file: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Setting configuration for interface %s from file %s\n", interfaceName, configFile)

	// Try to apply configuration via UAPI
	err = setInterfaceConfig(interfaceName, config)
	if err != nil {
		fmt.Printf("Failed to apply configuration via UAPI: %v\n", err)
		fmt.Println("Note: Make sure the interface is running with 'sudo ./wireguard-go <interface>'")

		// Show configuration summary as fallback
		fmt.Printf("\nConfiguration summary:\n")
		if config.Interface.PrivateKey != "" {
			fmt.Printf("  Interface private key: %s...\n", config.Interface.PrivateKey[:10])
		}
		if len(config.Interface.Address) > 0 {
			fmt.Printf("  Interface address: %s\n", strings.Join(config.Interface.Address, ", "))
		}
		fmt.Printf("  Number of peers: %d\n", len(config.Peers))
		return
	}

	fmt.Println("Configuration applied successfully!")
}

// Handle 'addconf' command - add peers from configuration file
func handleAddconf(args []string) {
	if len(args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: wg-go addconf <interface> <config-file>\n")
		os.Exit(1)
	}

	interfaceName := args[0]
	configFile := args[1]

	fmt.Printf("Adding configuration to interface %s from file %s\n", interfaceName, configFile)
	fmt.Println("Note: This is a demonstration. Real implementation would use UAPI.")
}

// Handle 'syncconf' command - synchronize configuration with file
func handleSyncconf(args []string) {
	if len(args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: wg-go syncconf <interface> <config-file>\n")
		os.Exit(1)
	}

	interfaceName := args[0]
	configFile := args[1]

	fmt.Printf("Synchronizing interface %s with file %s\n", interfaceName, configFile)
	fmt.Println("Note: This is a demonstration. Real implementation would use UAPI.")
}

// Handle 'showconf' command - show configuration in config file format
func handleShowconf(args []string) {
	if len(args) < 1 {
		fmt.Fprintf(os.Stderr, "Usage: wg-go showconf <interface>\n")
		os.Exit(1)
	}

	interfaceName := args[0]
	fmt.Printf("# Configuration for interface %s\n", interfaceName)
	fmt.Println("# Note: This is a demonstration. Real implementation would query UAPI.")
	fmt.Println("")
	fmt.Println("[Interface]")
	fmt.Println("# PrivateKey = <private-key-would-be-here>")
	fmt.Println("# Address = 10.0.0.1/24")
	fmt.Println("")
	fmt.Println("# [Peer]")
	fmt.Println("# PublicKey = <peer-public-key>")
	fmt.Println("# Endpoint = example.com:51820")
	fmt.Println("# AllowedIPs = 0.0.0.0/0")
}

// Show all WireGuard interfaces
func showAllInterfaces() {
	interfaces, err := discoverInterfaces()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error discovering interfaces: %v\n", err)
		return
	}

	if len(interfaces) == 0 {
		fmt.Println("No WireGuard interfaces found.")
		fmt.Println("To create an interface, run: sudo ./wireguard-go <interface-name>")
		return
	}

	for i, interfaceName := range interfaces {
		if i > 0 {
			fmt.Println()
		}

		info, err := getInterfaceInfo(interfaceName)
		if err != nil {
			fmt.Printf("interface: %s (error: %v)\n", interfaceName, err)
			continue
		}

		printInterfaceInfo(info, false)
	}
}

// Show specific WireGuard interface
func showInterface(name string) {
	info, err := getInterfaceInfo(name)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error getting interface info: %v\n", err)
		fmt.Printf("Make sure interface '%s' is running with: sudo ./wireguard-go %s\n", name, name)
		return
	}

	printInterfaceInfo(info, false)
}

// Configuration structures
type Config struct {
	Interface InterfaceConfig
	Peers     []PeerConfig
}

type InterfaceConfig struct {
	PrivateKey string
	Address    []string
	DNS        []string
	MTU        int
	ListenPort int
	Table      string
	PreUp      []string
	PostUp     []string
	PreDown    []string
	PostDown   []string
}

type PeerConfig struct {
	PublicKey           string
	PresharedKey        string
	Endpoint            string
	AllowedIPs          []string
	PersistentKeepalive int
}

// Parse WireGuard configuration file
func parseConfigFile(filename string) (*Config, error) {
	file, err := os.Open(filename)
	if err != nil {
		return nil, fmt.Errorf("cannot open config file: %v", err)
	}
	defer file.Close()

	config := &Config{}
	scanner := bufio.NewScanner(file)

	var currentSection string
	var currentPeer *PeerConfig

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		// Skip empty lines and comments
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		// Check for section headers
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			section := strings.ToLower(line[1 : len(line)-1])
			currentSection = section

			if section == "peer" {
				currentPeer = &PeerConfig{}
				config.Peers = append(config.Peers, *currentPeer)
				currentPeer = &config.Peers[len(config.Peers)-1]
			}
			continue
		}

		// Parse key-value pairs
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}

		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])

		switch currentSection {
		case "interface":
			err := parseInterfaceOption(&config.Interface, key, value)
			if err != nil {
				return nil, fmt.Errorf("error parsing interface option %s: %v", key, err)
			}
		case "peer":
			if currentPeer != nil {
				err := parsePeerOption(currentPeer, key, value)
				if err != nil {
					return nil, fmt.Errorf("error parsing peer option %s: %v", key, err)
				}
			}
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading config file: %v", err)
	}

	return config, nil
}

// Parse interface configuration option
func parseInterfaceOption(iface *InterfaceConfig, key, value string) error {
	switch strings.ToLower(key) {
	case "privatekey":
		iface.PrivateKey = value
	case "address":
		addresses := strings.Split(value, ",")
		for i, addr := range addresses {
			addresses[i] = strings.TrimSpace(addr)
		}
		iface.Address = addresses
	case "dns":
		dnsServers := strings.Split(value, ",")
		for i, dns := range dnsServers {
			dnsServers[i] = strings.TrimSpace(dns)
		}
		iface.DNS = dnsServers
	case "mtu":
		mtu, err := strconv.Atoi(value)
		if err != nil {
			return fmt.Errorf("invalid MTU value: %v", err)
		}
		iface.MTU = mtu
	case "listenport":
		port, err := strconv.Atoi(value)
		if err != nil {
			return fmt.Errorf("invalid listen port value: %v", err)
		}
		iface.ListenPort = port
	case "table":
		iface.Table = value
	case "preup":
		iface.PreUp = append(iface.PreUp, value)
	case "postup":
		iface.PostUp = append(iface.PostUp, value)
	case "predown":
		iface.PreDown = append(iface.PreDown, value)
	case "postdown":
		iface.PostDown = append(iface.PostDown, value)
	}
	return nil
}

// Parse peer configuration option
func parsePeerOption(peer *PeerConfig, key, value string) error {
	switch strings.ToLower(key) {
	case "publickey":
		peer.PublicKey = value
	case "presharedkey":
		peer.PresharedKey = value
	case "endpoint":
		// Validate endpoint format
		if strings.Contains(value, ":") {
			host, portStr, err := net.SplitHostPort(value)
			if err != nil {
				return fmt.Errorf("invalid endpoint format: %v", err)
			}

			// Validate port
			port, err := strconv.Atoi(portStr)
			if err != nil || port < 1 || port > 65535 {
				return fmt.Errorf("invalid port in endpoint: %s", portStr)
			}

			// Reconstruct to ensure consistent format
			peer.Endpoint = net.JoinHostPort(host, portStr)
		} else {
			peer.Endpoint = value
		}
	case "allowedips":
		allowedIPs := strings.Split(value, ",")
		for i, ip := range allowedIPs {
			allowedIPs[i] = strings.TrimSpace(ip)
		}
		peer.AllowedIPs = allowedIPs
	case "persistentkeepalive":
		keepalive, err := strconv.Atoi(value)
		if err != nil {
			return fmt.Errorf("invalid persistent keepalive value: %v", err)
		}
		peer.PersistentKeepalive = keepalive
	}
	return nil
}

// Handle 'dns' command - manage DNS monitoring settings
func handleDNS(args []string) {
	if len(args) < 1 {
		fmt.Fprintf(os.Stderr, "Error: DNS command requires interface name\n")
		fmt.Fprintf(os.Stderr, "Usage: wg-go dns <interface> [show|interval_seconds]\n")
		os.Exit(1)
	}

	interfaceName := args[0]

	// Connect to the interface via UAPI
	conn, err := connectToInterface(interfaceName)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error connecting to interface '%s': %v\n", interfaceName, err)
		os.Exit(1)
	}
	defer conn.Close()

	if len(args) == 1 || (len(args) == 2 && args[1] == "show") {
		// Show current DNS monitoring status
		showDNSMonitoringStatus(conn, interfaceName)
	} else if len(args) == 2 {
		// Set DNS monitoring interval
		intervalStr := args[1]
		interval, err := strconv.Atoi(intervalStr)
		if err != nil || interval <= 0 {
			fmt.Fprintf(os.Stderr, "Error: Invalid interval '%s'. Must be a positive number of seconds.\n", intervalStr)
			os.Exit(1)
		}

		setDNSMonitoringInterval(conn, interfaceName, interval)
	} else {
		fmt.Fprintf(os.Stderr, "Error: Too many arguments for DNS command\n")
		fmt.Fprintf(os.Stderr, "Usage: wg-go dns <interface> [show|interval_seconds]\n")
		os.Exit(1)
	}
}

// Show DNS monitoring status for an interface
func showDNSMonitoringStatus(conn net.Conn, interfaceName string) {
	fmt.Printf("DNS Monitoring Status for %s:\n", interfaceName)
	fmt.Println(strings.Repeat("=", 40))

	// Request interface status via UAPI
	_, err := fmt.Fprintf(conn, "get=1\n\n")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error requesting status: %v\n", err)
		return
	}

	// Parse response
	scanner := bufio.NewScanner(conn)
	var dnsInterval, monitoredPeers int
	var hasDNSInfo bool

	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			break // End of response
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}

		key, value := parts[0], parts[1]
		switch key {
		case "dns_monitor_interval":
			if interval, err := strconv.Atoi(value); err == nil {
				dnsInterval = interval
				hasDNSInfo = true
			}
		case "dns_monitored_peers":
			if peers, err := strconv.Atoi(value); err == nil {
				monitoredPeers = peers
			}
		}
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "Error reading response: %v\n", err)
		return
	}

	if !hasDNSInfo {
		fmt.Printf("❌ DNS monitoring is not available for this interface\n")
		fmt.Printf("   This may be because the interface is not running or\n")
		fmt.Printf("   DNS monitoring is not enabled.\n")
		return
	}

	// Display DNS monitoring information
	fmt.Printf("✅ DNS monitoring is active\n")
	fmt.Printf("📅 Check interval: %d seconds\n", dnsInterval)
	fmt.Printf("👥 Monitored peers: %d\n", monitoredPeers)

	if monitoredPeers == 0 {
		fmt.Printf("\n💡 No peers with domain endpoints are currently configured.\n")
		fmt.Printf("   To monitor domain endpoints, add peers with domain names like:\n")
		fmt.Printf("   Endpoint = vpn.example.com:51820\n")
	} else {
		fmt.Printf("\n🔍 Monitoring %d peer(s) with domain-based endpoints\n", monitoredPeers)
	}

	fmt.Printf("\n📊 For detailed monitoring, use: wg-go monitor %s\n", interfaceName)
}

// Set DNS monitoring interval
func setDNSMonitoringInterval(conn net.Conn, interfaceName string, intervalSeconds int) {
	fmt.Printf("Setting DNS monitoring interval for %s to %d seconds...\n", interfaceName, intervalSeconds)

	// Send UAPI command to set DNS monitoring interval
	_, err := fmt.Fprintf(conn, "set=1\ndns_monitor_interval=%d\n\n", intervalSeconds)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error sending configuration: %v\n", err)
		return
	}

	// Read response
	scanner := bufio.NewScanner(conn)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "errno=") {
			errno := strings.TrimPrefix(line, "errno=")
			if errno != "0" {
				if errno == "-22" {
					fmt.Fprintf(os.Stderr, "❌ DNS monitoring not supported: This interface was not created with DNS monitoring support.\n")
					fmt.Fprintf(os.Stderr, "   The interface may have been created by a different WireGuard implementation\n")
					fmt.Fprintf(os.Stderr, "   that doesn't include dynamic DNS functionality.\n")
					fmt.Fprintf(os.Stderr, "\n💡 To use DNS monitoring:\n")
					fmt.Fprintf(os.Stderr, "   1. Stop the current interface\n")
					fmt.Fprintf(os.Stderr, "   2. Create a new interface with this enhanced wg-go version\n")
				} else {
					fmt.Fprintf(os.Stderr, "Error setting DNS monitoring interval: errno=%s\n", errno)
				}
				return
			}
			break
		}
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "Error reading response: %v\n", err)
		return
	}

	fmt.Printf("✅ DNS monitoring interval successfully set to %d seconds\n", intervalSeconds)
}
