/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2017-2025 WireGuard LLC. All Rights Reserved.
 */

package main

import (
	"fmt"
	"io"
	"log"
	"os"
	"os/signal"
	"path/filepath"

	"golang.org/x/sys/windows"

	"golang.zx2c4.com/wireguard/conn"
	"golang.zx2c4.com/wireguard/device"
	"golang.zx2c4.com/wireguard/ipc"

	"golang.zx2c4.com/wireguard/tun"
)

const (
	ExitSetupSuccess = 0
	ExitSetupFailed  = 1
)

func main() {
	if len(os.Args) != 2 {
		os.Exit(ExitSetupFailed)
	}
	interfaceName := os.Args[1]

	// fmt.Fprintln(os.Stderr, "Warning: this is a test program for Windows, mainly used for debugging this Go package. For a real WireGuard for Windows client, the repo you want is <https://git.zx2c4.com/wireguard-windows/>, which includes this code as a module.")

	// Setup log file if specified
	var logWriter io.Writer = os.Stderr
	logFile := os.Getenv("LOG_FILE")
	if logFile == "" {
		// Default log file in current directory
		logFile = "wireguard-go.log"
	}

	// Check if we should log only to file (not to console)
	// Default to file-only logging unless explicitly set to "false"
	logFileOnly := os.Getenv("LOG_FILE_ONLY") != "false"

	// Create log file
	if logFile != "" && logFile != "-" {
		// Ensure directory exists
		logDir := filepath.Dir(logFile)
		if logDir != "." {
			os.MkdirAll(logDir, 0755)
		}

		file, err := os.OpenFile(logFile, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			log.Printf("Failed to open log file %s: %v, using stderr", logFile, err)
			logWriter = os.Stderr
		} else {
			if logFileOnly {
				// Only write to file, not to console (default behavior)
				logWriter = file
				fmt.Fprintf(os.Stderr, "Debug logging enabled, output to file only: %s\n", logFile)
			} else {
				// Use both file and stderr for logging (when explicitly enabled)
				logWriter = io.MultiWriter(os.Stderr, file)
				fmt.Fprintf(os.Stderr, "Debug logging enabled, output to both console and file: %s\n", logFile)
			}
		}
	}

	// get log level (default: debug/verbose)
	logLevel := func() int {
		switch os.Getenv("LOG_LEVEL") {
		case "verbose", "debug":
			return device.LogLevelVerbose
		case "error":
			return device.LogLevelError
		case "silent":
			return device.LogLevelSilent
		}
		// Default to verbose/debug level
		return device.LogLevelVerbose
	}()

	logger := device.NewLoggerWithWriter(
		logLevel,
		fmt.Sprintf("(%s) ", interfaceName),
		logWriter,
	)
	logger.Verbosef("Starting wireguard-go version %s", Version)

	tun, err := tun.CreateTUN(interfaceName, 0)
	if err == nil {
		realInterfaceName, err2 := tun.Name()
		if err2 == nil {
			interfaceName = realInterfaceName
		}
	} else {
		logger.Errorf("Failed to create TUN device: %v", err)
		os.Exit(ExitSetupFailed)
	}

	device := device.NewDevice(tun, conn.NewDefaultBind(), logger)
	err = device.Up()
	if err != nil {
		logger.Errorf("Failed to bring up device: %v", err)
		os.Exit(ExitSetupFailed)
	}
	logger.Verbosef("Device started")

	// Start DNS monitoring
	if device.GetDNSMonitor() != nil {
		device.GetDNSMonitor().Start()
		logger.Verbosef("DNS monitoring started")
	}

	uapi, err := ipc.UAPIListen(interfaceName)
	if err != nil {
		logger.Errorf("Failed to listen on uapi socket: %v", err)
		os.Exit(ExitSetupFailed)
	}

	errs := make(chan error)
	term := make(chan os.Signal, 1)

	go func() {
		for {
			conn, err := uapi.Accept()
			if err != nil {
				errs <- err
				return
			}
			go device.IpcHandle(conn)
		}
	}()
	logger.Verbosef("UAPI listener started")

	// wait for program to terminate

	signal.Notify(term, os.Interrupt)
	signal.Notify(term, os.Kill)
	signal.Notify(term, windows.SIGTERM)

	select {
	case <-term:
	case <-errs:
	case <-device.Wait():
	}

	// clean up

	// Stop DNS monitoring
	if device.GetDNSMonitor() != nil {
		device.GetDNSMonitor().Stop()
		logger.Verbosef("DNS monitoring stopped")
	}

	uapi.Close()
	device.Close()

	logger.Verbosef("Shutting down")
}
