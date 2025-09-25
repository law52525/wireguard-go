package main

import (
	"fmt"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		return
	}

	command := os.Args[1]
	args := os.Args[2:]

	switch command {
	case "genkey":
		handleGenkey()
	case "pubkey":
		handlePubkey(args)
	case "genpsk":
		handleGenpsk()
	case "show":
		handleShow(args)
	case "set":
		handleSet(args)
	case "setconf":
		handleSetconf(args)
	case "addconf":
		handleAddconf(args)
	case "syncconf":
		handleSyncconf(args)
	case "showconf":
		handleShowconf(args)
	case "monitor":
		handleMonitor(args)
	case "dns":
		handleDNS(args)
	case "help", "--help", "-h":
		printUsage()
	default:
		fmt.Printf("Unknown command: %s\n", command)
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Printf(`wg-go - Go implementation of WireGuard tools

Usage:
    wg-go <command> [arguments]

Commands:
    genkey                          Generate a new private key
    pubkey                          Calculate public key from private key (stdin)
    genpsk                          Generate a new preshared key
    show [interface]                Show current WireGuard configuration
    set <interface> <options>       Set WireGuard configuration
    setconf <interface> <file>      Set WireGuard configuration from file
    addconf <interface> <file>      Add peers from configuration file
    syncconf <interface> <file>     Synchronize configuration with file
    showconf <interface>            Show current configuration in config format
    monitor [interface] [interval]  Monitor interface status (live updates)
    dns <interface> [show|interval] DNS monitoring management

Examples:
    wg-go genkey                    Generate a private key
    wg-go genkey | wg-go pubkey     Generate a key pair
    wg-go show                      Show all WireGuard interfaces
    wg-go show wg0                  Show wg0 interface details
    wg-go setconf wg0 wg0.conf      Apply configuration file to wg0
    wg-go monitor                   Monitor all interfaces (live)
    wg-go monitor utun2 10          Monitor utun2 every 10 seconds
    wg-go dns wg0 show              Show DNS monitoring status for wg0
    wg-go dns wg0 30                Set DNS monitoring interval to 30 seconds

For more information, visit: https://www.wireguard.com/
`)
}
