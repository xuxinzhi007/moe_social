package handler

import (
	"encoding/json"
	"net/http"

	"backend/deploy/runner"
)

func (h *Handler) buildCache(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		st, err := runner.BuildCacheInfo(h.Cfg.BuildCacheAbs(), h.Cfg.BackendAbs())
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]any{
				"success": false,
				"message": err.Error(),
			})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"success": true, "cache": st})
	case http.MethodPost:
		var body struct {
			RemoveBinaries bool `json:"remove_binaries"`
		}
		if r.Body != nil {
			_ = json.NewDecoder(r.Body).Decode(&body)
		}
		freed, err := runner.CleanBuildCache(
			h.Cfg.BuildCacheAbs(),
			h.Cfg.BackendAbs(),
			body.RemoveBinaries,
		)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]any{
				"success": false,
				"message": err.Error(),
			})
			return
		}
		st, _ := runner.BuildCacheInfo(h.Cfg.BuildCacheAbs(), h.Cfg.BackendAbs())
		writeJSON(w, http.StatusOK, map[string]any{
			"success":     true,
			"message":     "编译缓存已清理",
			"freed_bytes": freed,
			"cache":       st,
		})
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}
