package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

// Handle 'monitor' command - continuously monitor WireGuard interfaces
func handleMonitor(args []string) {
	var interfaceName string
	refresh := 5 * time.Second

	if len(args) > 0 {
		interfaceName = args[0]
	}

	if len(args) > 1 {
		if interval, err := time.ParseDuration(args[1] + "s"); err == nil {
			refresh = interval
		}
	}

	fmt.Printf("WireGuard Interface Monitor (refresh every %v)\n", refresh)
	fmt.Println("Press Ctrl+C to exit")
	fmt.Println(strings.Repeat("=", 60))

	for {
		// Clear screen
		clearScreen()

		// Print header
		fmt.Printf("WireGuard Monitor - %s\n", time.Now().Format("2006-01-02 15:04:05"))
		fmt.Println(strings.Repeat("=", 60))

		if interfaceName != "" {
			// Monitor specific interface
			monitorSpecificInterface(interfaceName)
		} else {
			// Monitor all interfaces
			monitorAllInterfaces()
		}

		fmt.Printf("\nNext update in %v... (Press Ctrl+C to exit)\n", refresh)
		time.Sleep(refresh)
	}
}

// Monitor specific interface
func monitorSpecificInterface(name string) {
	info, err := getInterfaceInfo(name)
	if err != nil {
		fmt.Printf("❌ Error monitoring interface '%s': %v\n", name, err)
		fmt.Printf("💡 Make sure the interface is running: %s\n", strings.Replace(getStartCommand(), "<interface-name>", name, 1))
		return
	}

	printInterfaceInfoWithStats(info)
}

// Monitor all interfaces
func monitorAllInterfaces() {
	interfaces, err := discoverInterfaces()
	if err != nil {
		fmt.Printf("❌ Error discovering interfaces: %v\n", err)
		return
	}

	if len(interfaces) == 0 {
		fmt.Println("📭 No WireGuard interfaces found")
		fmt.Printf("💡 To create an interface: %s\n", getStartCommand())
		return
	}

	fmt.Printf("📡 Found %d WireGuard interface(s):\n\n", len(interfaces))

	for i, interfaceName := range interfaces {
		if i > 0 {
			fmt.Println()
		}

		info, err := getInterfaceInfo(interfaceName)
		if err != nil {
			fmt.Printf("interface: %s ❌ (error: %v)\n", interfaceName, err)
			continue
		}

		printInterfaceInfoWithStats(info)
	}
}

// Print interface information with enhanced statistics
func printInterfaceInfoWithStats(info *InterfaceInfo) {
	// Interface header
	fmt.Printf("🔌 Interface: %s\n", info.Name)

	if info.PublicKey != "" {
		fmt.Printf("  🔑 Public key: %s\n", info.PublicKey)
	}

	fmt.Printf("  🔒 Private key: %s\n", "(hidden)")

	if info.ListenPort > 0 {
		fmt.Printf("  🌐 Listening port: %d\n", info.ListenPort)
	}

	if info.FwMark > 0 {
		fmt.Printf("  🏷️  Firewall mark: 0x%x\n", info.FwMark)
	}

	// Peer information
	if len(info.Peers) == 0 {
		fmt.Printf("  👥 Peers: none configured\n")
		return
	}

	fmt.Printf("  👥 Peers: %d\n", len(info.Peers))

	for i, peer := range info.Peers {
		fmt.Printf("\n  📡 Peer %d:\n", i+1)
		fmt.Printf("    🔑 Public key: %s\n", peer.PublicKey)

		if peer.Endpoint != "" {
			fmt.Printf("    🎯 Endpoint: %s\n", peer.Endpoint)
		} else {
			fmt.Printf("    🎯 Endpoint: (not set)\n")
		}

		if len(peer.AllowedIPs) > 0 {
			fmt.Printf("    🛡️  Allowed IPs: %s\n", strings.Join(peer.AllowedIPs, ", "))
		}

		// Connection status
		lastHandshake := peer.LastHandshakeTime()
		if !lastHandshake.IsZero() {
			elapsed := time.Since(lastHandshake)
			status := "🟢 Active"
			if elapsed > 3*time.Minute {
				status = "🟡 Inactive"
			}
			if elapsed > 10*time.Minute {
				status = "🔴 Stale"
			}

			fmt.Printf("    🤝 Last handshake: %s (%s ago) %s\n",
				lastHandshake.Format("15:04:05"),
				formatDuration(elapsed),
				status)
		} else {
			fmt.Printf("    🤝 Last handshake: never 🔴\n")
		}

		// Traffic statistics
		if peer.TxBytes > 0 || peer.RxBytes > 0 {
			fmt.Printf("    📊 Traffic: ⬇️ %s received, ⬆️ %s sent\n",
				formatBytes(peer.RxBytes), formatBytes(peer.TxBytes))

			// Calculate rates (simplified)
			if !lastHandshake.IsZero() {
				elapsed := time.Since(lastHandshake)
				if elapsed > 0 && elapsed < time.Hour {
					rxRate := float64(peer.RxBytes) / elapsed.Seconds()
					txRate := float64(peer.TxBytes) / elapsed.Seconds()
					fmt.Printf("    📈 Average rate: ⬇️ %s/s, ⬆️ %s/s\n",
						formatBytes(int64(rxRate)), formatBytes(int64(txRate)))
				}
			}
		} else {
			fmt.Printf("    📊 Traffic: no data transferred\n")
		}

		if peer.PersistentKeepaliveInterval > 0 {
			fmt.Printf("    💓 Keepalive: every %d seconds\n", peer.PersistentKeepaliveInterval)
		}
	}
}

// Format duration in a human-readable way
func formatDuration(d time.Duration) string {
	if d < time.Minute {
		return fmt.Sprintf("%.0fs", d.Seconds())
	} else if d < time.Hour {
		return fmt.Sprintf("%.0fm", d.Minutes())
	} else if d < 24*time.Hour {
		return fmt.Sprintf("%.1fh", d.Hours())
	} else {
		return fmt.Sprintf("%.1fd", d.Hours()/24)
	}
}

// Clear screen (cross-platform)
func clearScreen() {
	cmd := exec.Command("clear")
	if _, err := exec.LookPath("clear"); err != nil {
		// Windows
		cmd = exec.Command("cmd", "/c", "cls")
	}
	cmd.Stdout = os.Stdout
	cmd.Run()
}
