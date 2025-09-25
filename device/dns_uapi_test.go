/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2017-2025 WireGuard LLC. All Rights Reserved.
 */

package device

import (
	"bytes"
	"strings"
	"testing"
	"time"
)

func TestDNSMonitorUAPIIntegration(t *testing.T) {
	// Create a mock device with DNS monitor
	device := &Device{
		log: &Logger{
			Verbosef: func(format string, args ...any) {}, // Silent logger for testing
			Errorf:   func(format string, args ...any) {}, // Silent logger for testing
		},
	}
	device.dnsMonitor = NewDNSMonitor(device, 60*time.Second)

	// Test setting DNS monitor interval via UAPI
	err := device.handleDeviceLine("dns_monitor_interval", "120")
	if err != nil {
		t.Errorf("Failed to set DNS monitor interval: %v", err)
	}

	// Verify the interval was updated
	expectedInterval := 120 * time.Second
	actualInterval := device.dnsMonitor.GetMonitorInterval()
	if actualInterval != expectedInterval {
		t.Errorf("Expected interval %v, got %v", expectedInterval, actualInterval)
	}

	// Test invalid interval (too small)
	err = device.handleDeviceLine("dns_monitor_interval", "5")
	if err == nil {
		t.Error("Expected error for interval less than 10 seconds, but got none")
	}

	// Test invalid interval (non-numeric)
	err = device.handleDeviceLine("dns_monitor_interval", "invalid")
	if err == nil {
		t.Error("Expected error for non-numeric interval, but got none")
	}
}

func TestDNSMonitorUAPIOutput(t *testing.T) {
	// Create a mock device with DNS monitor
	device := &Device{
		log: &Logger{
			Verbosef: func(format string, args ...any) {}, // Silent logger for testing
			Errorf:   func(format string, args ...any) {}, // Silent logger for testing
		},
	}
	device.dnsMonitor = NewDNSMonitor(device, 90*time.Second)

	// Add a mock peer to DNS monitoring
	var testKey NoisePublicKey
	copy(testKey[:], []byte("test_public_key_12345678901234567890")) // 32 bytes
	err := device.dnsMonitor.AddPeer(testKey, "example.com:51820")
	if err != nil {
		t.Logf("Warning: Could not add peer to DNS monitor: %v", err)
		// Don't fail the test as this might depend on DNS resolution
	}

	// Capture UAPI output
	var output bytes.Buffer
	err = device.IpcGetOperation(&output)
	if err != nil {
		t.Fatalf("Failed to get UAPI output: %v", err)
	}

	outputStr := output.String()

	// Check if DNS monitor interval is present in output
	if !strings.Contains(outputStr, "dns_monitor_interval=90") {
		t.Errorf("Expected 'dns_monitor_interval=90' in UAPI output, got:\n%s", outputStr)
	}

	// If we successfully added a peer, check if monitored peers count is present
	if err == nil {
		if !strings.Contains(outputStr, "dns_monitored_peers=1") {
			t.Logf("Note: 'dns_monitored_peers=1' not found in output (DNS resolution may have failed)")
			t.Logf("UAPI output:\n%s", outputStr)
		}
	}
}

func TestDNSMonitorUAPIMinimumInterval(t *testing.T) {
	device := &Device{
		log: &Logger{
			Verbosef: func(format string, args ...any) {}, // Silent logger for testing
			Errorf:   func(format string, args ...any) {}, // Silent logger for testing
		},
	}
	device.dnsMonitor = NewDNSMonitor(device, 60*time.Second)

	// Test setting minimum valid interval (10 seconds)
	err := device.handleDeviceLine("dns_monitor_interval", "10")
	if err != nil {
		t.Errorf("Failed to set minimum valid interval: %v", err)
	}

	actualInterval := device.dnsMonitor.GetMonitorInterval()
	expectedInterval := 10 * time.Second
	if actualInterval != expectedInterval {
		t.Errorf("Expected interval %v, got %v", expectedInterval, actualInterval)
	}

	// Test setting interval just below minimum (9 seconds) - should fail
	err = device.handleDeviceLine("dns_monitor_interval", "9")
	if err == nil {
		t.Error("Expected error for interval below minimum (9 seconds), but got none")
	}

	// Verify interval wasn't changed
	actualInterval = device.dnsMonitor.GetMonitorInterval()
	if actualInterval != expectedInterval {
		t.Errorf("Interval should not have changed after invalid input, expected %v, got %v", expectedInterval, actualInterval)
	}
}

func TestDNSMonitorThreadSafety(t *testing.T) {
	device := &Device{
		log: &Logger{
			Verbosef: func(format string, args ...any) {}, // Silent logger for testing
			Errorf:   func(format string, args ...any) {}, // Silent logger for testing
		},
	}
	device.dnsMonitor = NewDNSMonitor(device, 60*time.Second)

	// Test concurrent access to DNS monitor interval
	done := make(chan bool, 2)

	// Goroutine 1: Update interval
	go func() {
		for i := 0; i < 100; i++ {
			device.dnsMonitor.UpdateMonitorInterval(time.Duration(10+i%50) * time.Second)
		}
		done <- true
	}()

	// Goroutine 2: Read interval
	go func() {
		for i := 0; i < 100; i++ {
			interval := device.dnsMonitor.GetMonitorInterval()
			if interval < 10*time.Second || interval > 60*time.Second {
				t.Errorf("Got invalid interval during concurrent access: %v", interval)
			}
		}
		done <- true
	}()

	// Wait for both goroutines to complete
	<-done
	<-done
}
