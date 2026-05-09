package common

import (
	"net/http"
)

// ApplyOllamaForwardHeaders adds compatibility headers for Ollama proxy targets.
// Free ngrok domains may reject programmatic requests without this header.
func ApplyOllamaForwardHeaders(req *http.Request) {
	if req == nil || req.URL == nil {
		return
	}
	req.Header.Set("ngrok-skip-browser-warning", "true")
	if req.Header.Get("User-Agent") == "" {
		req.Header.Set("User-Agent", "moe-social-backend/1.0")
	}
}
