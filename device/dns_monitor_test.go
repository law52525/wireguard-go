/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2017-2025 WireGuard LLC. All Rights Reserved.
 */

package device

import (
	"net"
	"testing"
	"time"
)

func TestIsDomainEndpoint(t *testing.T) {
	tests := []struct {
		endpoint string
		expected bool
	}{
		{"example.com:51820", true},
		{"192.168.1.1:51820", false},
		{"2001:db8::1:51820", false},
		{"localhost:51820", true},
		{"vpn.example.org:12345", true},
		{"[2001:db8::1]:51820", false},
		{"invalid", false}, // Invalid format should return false
	}

	for _, test := range tests {
		result := IsDomainEndpoint(test.endpoint)
		if result != test.expected {
			t.Errorf("IsDomainEndpoint(%s) = %v, expected %v", test.endpoint, result, test.expected)
		}
	}
}

func TestExtractDomainFromEndpoint(t *testing.T) {
	tests := []struct {
		endpoint       string
		expectedDomain string
		expectError    bool
	}{
		{"example.com:51820", "example.com", false},
		{"vpn.example.org:12345", "vpn.example.org", false},
		{"192.168.1.1:51820", "", true},   // IP address should error
		{"[2001:db8::1]:51820", "", true}, // IPv6 should error
		{"invalid", "", true},             // Invalid format should error
	}

	for _, test := range tests {
		domain, err := ExtractDomainFromEndpoint(test.endpoint)

		if test.expectError {
			if err == nil {
				t.Errorf("ExtractDomainFromEndpoint(%s) expected error but got none", test.endpoint)
			}
		} else {
			if err != nil {
				t.Errorf("ExtractDomainFromEndpoint(%s) unexpected error: %v", test.endpoint, err)
			}
			if domain != test.expectedDomain {
				t.Errorf("ExtractDomainFromEndpoint(%s) = %s, expected %s", test.endpoint, domain, test.expectedDomain)
			}
		}
	}
}

func TestDNSMonitorCreation(t *testing.T) {
	// Create a mock device
	device := &Device{
		log: &Logger{
			Verbosef: func(format string, args ...any) {}, // Silent logger for testing
			Errorf:   func(format string, args ...any) {}, // Silent logger for testing
		},
	}

	// Test creating DNS monitor with valid interval
	monitor := NewDNSMonitor(device, 30*time.Second)
	if monitor == nil {
		t.Fatal("NewDNSMonitor returned nil")
	}

	if monitor.interval != 30*time.Second {
		t.Errorf("Expected interval 30s, got %v", monitor.interval)
	}

	// Test creating DNS monitor with invalid interval (should use default)
	monitor2 := NewDNSMonitor(device, -1*time.Second)
	if monitor2.interval != 60*time.Second {
		t.Errorf("Expected default interval 60s for invalid input, got %v", monitor2.interval)
	}
}

func TestResolveDomain(t *testing.T) {
	// Create a mock device
	device := &Device{
		log: &Logger{
			Verbosef: func(format string, args ...any) {}, // Silent logger for testing
			Errorf:   func(format string, args ...any) {}, // Silent logger for testing
		},
	}

	monitor := NewDNSMonitor(device, 60*time.Second)

	// Test resolving localhost (should work on most systems)
	ip, err := monitor.resolveDomain("localhost")
	if err != nil {
		t.Logf("Warning: Could not resolve localhost: %v", err)
		// Don't fail the test as DNS resolution depends on system configuration
	} else {
		// Verify it's a valid IP address
		if net.ParseIP(ip) == nil {
			t.Errorf("resolveDomain returned invalid IP: %s", ip)
		}
	}

	// Test resolving invalid domain
	_, err = monitor.resolveDomain("invalid.domain.that.should.not.exist.12345")
	if err == nil {
		t.Log("Warning: Expected error for invalid domain, but resolution succeeded")
		// Don't fail as this might work in some DNS configurations
	}
}

func TestDNSMonitorUpdateInterval(t *testing.T) {
	// Create a mock device
	device := &Device{
		log: &Logger{
			Verbosef: func(format string, args ...any) {}, // Silent logger for testing
			Errorf:   func(format string, args ...any) {}, // Silent logger for testing
		},
	}

	monitor := NewDNSMonitor(device, 60*time.Second)

	// Test updating interval
	newInterval := 120 * time.Second
	monitor.UpdateMonitorInterval(newInterval)

	if monitor.interval != newInterval {
		t.Errorf("Expected interval %v, got %v", newInterval, monitor.interval)
	}

	// Test updating with invalid interval (should be ignored)
	monitor.UpdateMonitorInterval(-1 * time.Second)
	if monitor.interval != newInterval {
		t.Errorf("Invalid interval should be ignored, expected %v, got %v", newInterval, monitor.interval)
	}
}
