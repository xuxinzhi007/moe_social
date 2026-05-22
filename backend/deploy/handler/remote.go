package handler

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"time"

	"backend/deploy/runner"
)

func (h *Handler) remoteCheck(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	ctx, cancel := contextWithTimeout(r, 60*time.Second)
	defer cancel()
	targetID := r.URL.Query().Get("target")
	if targetID == "" {
		targetID = "cloud"
	}
	check, err := runner.RunRemoteCheck(ctx, h.Cfg, targetID)
	if err != nil && check.Message == "" {
		check.Message = err.Error()
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"success": check.OK,
		"check":   check,
		"target":  h.Cfg.TargetByID(targetID),
	})
}

func (h *Handler) remoteConfig(w http.ResponseWriter, r *http.Request) {
	targetID := r.URL.Query().Get("target")
	if targetID == "" {
		targetID = "cloud"
	}
	switch r.Method {
	case http.MethodGet:
		h.remoteConfigRead(w, r, targetID)
	case http.MethodPut:
		h.remoteConfigWrite(w, r, targetID)
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func (h *Handler) remoteConfigRead(w http.ResponseWriter, r *http.Request, targetID string) {
	ctx, cancel := contextWithTimeout(r, 90*time.Second)
	defer cancel()
	fileName := r.URL.Query().Get("file")
	if fileName == "" {
		fileName = "docker-compose.binary.yml"
	}
	content, remotePath, err := runner.ReadRemoteConfig(ctx, h.Cfg, targetID, fileName)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"success": false,
			"message": err.Error(),
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"success":     true,
		"file":        fileName,
		"remote_path": remotePath,
		"content":     content,
		"target":      h.Cfg.TargetByID(targetID),
	})
}

type remoteConfigWriteBody struct {
	Target  string `json:"target"`
	File    string `json:"file"`
	Content string `json:"content"`
}

func (h *Handler) remoteConfigWrite(w http.ResponseWriter, r *http.Request, targetID string) {
	ctx, cancel := contextWithTimeout(r, 90*time.Second)
	defer cancel()
	body, err := io.ReadAll(io.LimitReader(r.Body, 600*1024))
	if err != nil {
		http.Error(w, "read body", http.StatusBadRequest)
		return
	}
	var req remoteConfigWriteBody
	if err := json.Unmarshal(body, &req); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	if strings.TrimSpace(req.Target) != "" {
		targetID = strings.TrimSpace(req.Target)
	}
	if req.File == "" {
		req.File = "docker-compose.binary.yml"
	}
	remotePath, backupPath, err := runner.WriteRemoteConfig(ctx, h.Cfg, targetID, req.File, req.Content)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"success": false,
			"message": err.Error(),
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"success":     true,
		"message":     "已写入远程配置（已备份）",
		"remote_path": remotePath,
		"backup_path": backupPath,
		"target":      h.Cfg.TargetByID(targetID),
	})
}

func contextWithTimeout(r *http.Request, d time.Duration) (context.Context, context.CancelFunc) {
	return context.WithTimeout(r.Context(), d)
}
