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
