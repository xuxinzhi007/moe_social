package handler

import (
	"log"
	"net/http"
	"os"
	"runtime"
	"time"
)

var requestShutdown func()

// SetRequestShutdown registers graceful HTTP server shutdown (called from cmd/deploy-agent).
func SetRequestShutdown(fn func()) {
	requestShutdown = fn
}

func platformLabel() string {
	switch runtime.GOOS {
	case "darwin":
		return "macOS"
	case "windows":
		return "Windows"
	case "linux":
		return "Linux"
	default:
		return runtime.GOOS
	}
}

func (h *Handler) agentMeta(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"success":        true,
		"running":        true,
		"pid":            os.Getpid(),
		"listen":         h.Cfg.Listen,
		"platform":       runtime.GOOS,
		"platform_label": platformLabel(),
		"arch":           runtime.GOARCH,
	})
}

func (h *Handler) shutdownAgent(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	pid := os.Getpid()
	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"message": "Deploy Agent 正在退出",
		"pid":     pid,
	})
	go func() {
		time.Sleep(400 * time.Millisecond)
		if requestShutdown != nil {
			requestShutdown()
			return
		}
		log.Printf("Deploy Agent (pid=%d) exiting", pid)
		os.Exit(0)
	}()
}
