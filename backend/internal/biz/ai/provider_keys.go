package aibiz

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"

	"backend/utils"
)

const (
	providerKeysCipherVersion = "v1"
	providerKeysSecretEnv     = "MOE_AI_CONFIG_ENCRYPTION_KEY"
)

var errProviderKeysSecretMissing = errors.New(
	"AI provider key encryption secret is not configured",
)

func encodeProviderAPIKeys(keys map[string]string) (string, error) {
	normalized := normalizeProviderAPIKeys(keys)
	if len(normalized) == 0 {
		return "", nil
	}

	secret := providerKeysEncryptionSecret()
	if secret == "" {
		return "", errProviderKeysSecretMissing
	}
	key := sha256.Sum256([]byte(secret))
	block, err := aes.NewCipher(key[:])
	if err != nil {
		return "", fmt.Errorf("create provider key cipher: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", fmt.Errorf("create provider key gcm: %w", err)
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", fmt.Errorf("generate provider key nonce: %w", err)
	}
	plaintext, err := json.Marshal(normalized)
	if err != nil {
		return "", fmt.Errorf("encode provider keys: %w", err)
	}
	ciphertext := gcm.Seal(nil, nonce, plaintext, nil)
	return strings.Join([]string{
		providerKeysCipherVersion,
		base64.RawURLEncoding.EncodeToString(nonce),
		base64.RawURLEncoding.EncodeToString(ciphertext),
	}, ":"), nil
}

func decodeProviderAPIKeys(encoded string) (map[string]string, error) {
	encoded = strings.TrimSpace(encoded)
	if encoded == "" {
		return map[string]string{}, nil
	}
	parts := strings.Split(encoded, ":")
	if len(parts) != 3 || parts[0] != providerKeysCipherVersion {
		return nil, errors.New("unsupported AI provider key ciphertext")
	}
	nonce, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, fmt.Errorf("decode provider key nonce: %w", err)
	}
	ciphertext, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return nil, fmt.Errorf("decode provider key ciphertext: %w", err)
	}

	secret := providerKeysEncryptionSecret()
	if secret == "" {
		return nil, errProviderKeysSecretMissing
	}
	key := sha256.Sum256([]byte(secret))
	block, err := aes.NewCipher(key[:])
	if err != nil {
		return nil, fmt.Errorf("create provider key cipher: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("create provider key gcm: %w", err)
	}
	if len(nonce) != gcm.NonceSize() {
		return nil, errors.New("invalid AI provider key nonce")
	}
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return nil, fmt.Errorf("decrypt provider keys: %w", err)
	}
	var keys map[string]string
	if err := json.Unmarshal(plaintext, &keys); err != nil {
		return nil, fmt.Errorf("decode provider keys: %w", err)
	}
	return normalizeProviderAPIKeys(keys), nil
}

func providerAPIKeysJSON(keys map[string]string) (string, error) {
	raw, err := json.Marshal(normalizeProviderAPIKeys(keys))
	if err != nil {
		return "", fmt.Errorf("encode provider keys JSON: %w", err)
	}
	return string(raw), nil
}

func normalizeProviderAPIKeys(keys map[string]string) map[string]string {
	out := make(map[string]string, len(keys))
	for profileID, rawKey := range keys {
		profileID = strings.TrimSpace(profileID)
		apiKey := normalizeProviderAPIKey(rawKey)
		if profileID == "" || apiKey == "" {
			continue
		}
		out[profileID] = apiKey
	}
	return out
}

func normalizeProviderAPIKey(raw string) string {
	key := strings.TrimSpace(raw)
	if len(key) >= len("Bearer ") &&
		strings.EqualFold(key[:len("Bearer ")], "Bearer ") {
		key = strings.TrimSpace(key[len("Bearer "):])
	}
	return key
}

func providerKeysEncryptionSecret() string {
	if secret := strings.TrimSpace(os.Getenv(providerKeysSecretEnv)); secret != "" {
		return secret
	}
	return strings.TrimSpace(utils.ResolveAuthAccessSecret())
}
