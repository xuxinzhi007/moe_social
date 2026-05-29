package transport

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"backend/internal/apilegacy/common"
	"backend/internal/apilegacy/moebridge"
	moeadmin "backend/internal/service/moe"
	"backend/pkg/moe/runtime"

	"github.com/gorilla/websocket"
	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

var brainPipelineWSUpgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 4096,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

type brainPipelineWSMsg struct {
	Type    string      `json:"type"`
	Success bool        `json:"success,omitempty"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
}

func brainPipelineWSHandler(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		serveBrainPipelineWS(ctx.Response(), ctx.Request(), admin)
		return nil
	}
}

func serveBrainPipelineWS(w http.ResponseWriter, r *http.Request, admin *moeadmin.AdminService) {
	if _, errResp := common.RequireAdminToken(r); errResp != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		_ = json.NewEncoder(w).Encode(brainPipelineWSMsg{
			Type:    "error",
			Success: false,
			Message: errResp.Message,
		})
		return
	}
	agentKey := strings.TrimSpace(r.URL.Query().Get("agent_key"))
	if agentKey == "" {
		http.Error(w, "agent_key is required", http.StatusBadRequest)
		return
	}
	if admin == nil {
		http.Error(w, "MoeAdmin 未配置", http.StatusServiceUnavailable)
		return
	}

	conn, err := brainPipelineWSUpgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()

	ctx := r.Context()
	send := func(msg brainPipelineWSMsg) bool {
		_ = conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
		if err := conn.WriteJSON(msg); err != nil {
			return false
		}
		return true
	}

	pushSnapshot := func() (running bool) {
		snap, err := admin.GetBrainPipeline(ctx, agentKey)
		if err != nil {
			_ = send(brainPipelineWSMsg{
				Type:    "error",
				Success: false,
				Message: err.Error(),
			})
			return false
		}
		data := moebridge.PipelineDataFromBiz(snap)
		if !send(brainPipelineWSMsg{Type: "pipeline", Success: true, Data: data}) {
			return false
		}
		return snap.Running
	}

	if !pushSnapshot() {
		return
	}
	if !runtime.LiveRuns.IsRunning(agentKey) {
		_ = send(brainPipelineWSMsg{Type: "done", Success: true})
		return
	}

	updates, unsub := runtime.LiveRuns.Subscribe(agentKey)
	defer unsub()

	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if !pushSnapshot() {
				return
			}
			if !runtime.LiveRuns.IsRunning(agentKey) {
				_ = send(brainPipelineWSMsg{Type: "done", Success: true})
				return
			}
		case _, open := <-updates:
			if !open {
				return
			}
			if !pushSnapshot() {
				return
			}
			if !runtime.LiveRuns.IsRunning(agentKey) {
				_ = send(brainPipelineWSMsg{Type: "done", Success: true})
				return
			}
		}
	}
}
