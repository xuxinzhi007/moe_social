package common

import (
	"errors"
	"strings"
)

// ResolveOllamaBaseURL normalizes base URL from config and validates it.
func ResolveOllamaBaseURL(configured string) (string, error) {
	baseURL := strings.TrimRight(strings.TrimSpace(configured), "/")
	if baseURL == "" {
		return "", errors.New("ollama base url is empty, please set Ollama.BaseUrl in config")
	}
	return baseURL, nil
}
