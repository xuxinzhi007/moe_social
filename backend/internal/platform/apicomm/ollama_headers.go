package apicomm

import (
	"net/http"
)

// ApplyInferenceForwardHeaders adds compatibility headers for local inference proxies.
func ApplyInferenceForwardHeaders(req *http.Request) {
	if req == nil || req.URL == nil {
		return
	}
	req.Header.Set("ngrok-skip-browser-warning", "true")
	if req.Header.Get("User-Agent") == "" {
		req.Header.Set("User-Agent", "moe-social-backend/1.0")
	}
}

// ApplyOllamaForwardHeaders 已废弃，请使用 ApplyInferenceForwardHeaders。
func ApplyOllamaForwardHeaders(req *http.Request) {
	ApplyInferenceForwardHeaders(req)
}
