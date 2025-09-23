package main

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"

	"golang.org/x/crypto/curve25519"
)

const (
	// WireGuard key sizes
	PrivateKeySize   = 32
	PublicKeySize    = 32
	PresharedKeySize = 32
)

type PrivateKey [PrivateKeySize]byte
type PublicKey [PublicKeySize]byte
type PresharedKey [PresharedKeySize]byte

// Generate a new WireGuard private key
func generatePrivateKey() (PrivateKey, error) {
	var key PrivateKey

	// Generate random bytes
	_, err := rand.Read(key[:])
	if err != nil {
		return key, fmt.Errorf("failed to generate random key: %v", err)
	}

	// Clamp the key according to Curve25519 requirements
	clampPrivateKey(&key)

	return key, nil
}

// Generate a new preshared key
func generatePresharedKey() (PresharedKey, error) {
	var key PresharedKey

	_, err := rand.Read(key[:])
	if err != nil {
		return key, fmt.Errorf("failed to generate random preshared key: %v", err)
	}

	return key, nil
}

// Calculate public key from private key
func (sk PrivateKey) PublicKey() PublicKey {
	var pk PublicKey
	curve25519.ScalarBaseMult((*[32]byte)(&pk), (*[32]byte)(&sk))
	return pk
}

// Clamp private key according to Curve25519 requirements
func clampPrivateKey(key *PrivateKey) {
	key[0] &= 248                  // Clear the lowest 3 bits
	key[31] = (key[31] & 127) | 64 // Clear the highest bit and set the second highest bit
}

// Convert private key to base64 string
func (sk PrivateKey) String() string {
	return base64.StdEncoding.EncodeToString(sk[:])
}

// Convert public key to base64 string
func (pk PublicKey) String() string {
	return base64.StdEncoding.EncodeToString(pk[:])
}

// Convert preshared key to base64 string
func (psk PresharedKey) String() string {
	return base64.StdEncoding.EncodeToString(psk[:])
}

// Parse private key from base64 string
func parsePrivateKey(s string) (PrivateKey, error) {
	var key PrivateKey

	decoded, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		return key, fmt.Errorf("invalid base64 encoding: %v", err)
	}

	if len(decoded) != PrivateKeySize {
		return key, fmt.Errorf("invalid key size: expected %d bytes, got %d", PrivateKeySize, len(decoded))
	}

	copy(key[:], decoded)
	clampPrivateKey(&key)

	return key, nil
}

// Parse public key from base64 string
func parsePublicKey(s string) (PublicKey, error) {
	var key PublicKey

	decoded, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		return key, fmt.Errorf("invalid base64 encoding: %v", err)
	}

	if len(decoded) != PublicKeySize {
		return key, fmt.Errorf("invalid key size: expected %d bytes, got %d", PublicKeySize, len(decoded))
	}

	copy(key[:], decoded)
	return key, nil
}

// Parse preshared key from base64 string
func parsePresharedKey(s string) (PresharedKey, error) {
	var key PresharedKey

	decoded, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		return key, fmt.Errorf("invalid base64 encoding: %v", err)
	}

	if len(decoded) != PresharedKeySize {
		return key, fmt.Errorf("invalid key size: expected %d bytes, got %d", PresharedKeySize, len(decoded))
	}

	copy(key[:], decoded)
	return key, nil
}

// Convert key to hex string (for debugging)
func (sk PrivateKey) Hex() string {
	return hex.EncodeToString(sk[:])
}

// Convert public key to hex string (for debugging)
func (pk PublicKey) Hex() string {
	return hex.EncodeToString(pk[:])
}

// Validate that a private key is non-zero
func (sk PrivateKey) IsZero() bool {
	var zero PrivateKey
	return sk == zero
}

// Validate that a public key is non-zero
func (pk PublicKey) IsZero() bool {
	var zero PublicKey
	return pk == zero
}

// Validate that the key is a valid Curve25519 public key
func (pk PublicKey) IsValid() bool {
	// Check if the key is all zeros
	if pk.IsZero() {
		return false
	}

	// Additional validation could be added here
	// For now, we just check it's not zero
	return true
}

var (
	ErrInvalidKeySize = errors.New("invalid key size")
	ErrInvalidKey     = errors.New("invalid key")
	ErrZeroKey        = errors.New("key cannot be zero")
)
