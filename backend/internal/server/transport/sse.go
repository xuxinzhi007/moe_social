package transport

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"backend/internal/biz/moe/moebridge"
	"backend/internal/legacy/types"
	apicomm "backend/internal/platform/apicomm"
	moeadmin "backend/internal/service/moe"
	"backend/model"
	"backend/pkg/conf"
	"backend/pkg/llminference"
	"backend/pkg/moe/runtime"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func registerSSE(r *khttp.Router, admin *moeadmin.AdminService) {
	r.GET("/api/admin/moe/brain/pipeline/stream", streamMoeBrainPipeline(admin))
	r.POST("/api/admin/moe/inference/chat/stream", streamMoeInferenceChat(admin))
}

func moeAdminUnavailable() types.BaseResp {
	return types.BaseResp{Code: -1, Message: "MoeAdmin unavailable", Success: false}
}

func streamMoeBrainPipeline(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		w := ctx.Response()
		r := ctx.Request()
		// GET + EventSource 不带 Content-Type，不能用 ctx.Bind（body 解码器会回 400 CODEC）；
		// 也不能用 ctx.BindQuery（它认 json tag，而这个 legacy 结构体只有 form tag）。
		agentKey := r.URL.Query().Get("agent_key")
		if agentKey == "" {
			_ = apicomm.WriteSSE(w, "error", types.AdminGetMoeBrainPipelineResp{
				BaseResp: apicomm.HandleError(fmt.Errorf("agent_key is required")),
			})
			return nil
		}
		if admin == nil {
			_ = apicomm.WriteSSE(w, "error", types.AdminGetMoeBrainPipelineResp{
				BaseResp: moeAdminUnavailable(),
			})
			return nil
		}

		apicomm.InitSSEHeaders(w)
		w.WriteHeader(http.StatusOK)

		send := func() bool {
			snap, err := admin.GetBrainPipeline(r.Context(), agentKey)
			if err != nil {
				_ = apicomm.WriteSSE(w, "error", types.AdminGetMoeBrainPipelineResp{
					BaseResp: apicomm.HandleError(err),
				})
				return false
			}
			if err := apicomm.WriteSSE(w, "pipeline", types.AdminGetMoeBrainPipelineResp{
				BaseResp: apicomm.HandleError(nil),
				Data:     moebridge.PipelineDataFromBiz(snap),
			}); err != nil {
				return false
			}
			return !snap.Running
		}

		if send() {
			_ = apicomm.WriteSSE(w, "done", map[string]bool{"ok": true})
			return nil
		}

		updates, unsub := runtime.LiveRuns.Subscribe(agentKey)
		defer unsub()

		heartbeat := time.NewTicker(25 * time.Second)
		defer heartbeat.Stop()

		for {
			select {
			case <-r.Context().Done():
				return nil
			case <-heartbeat.C:
				if err := apicomm.WriteSSE(w, "ping", map[string]string{"t": "ok"}); err != nil {
					return nil
				}
			case _, open := <-updates:
				if !open {
					return nil
				}
				if send() {
					_ = apicomm.WriteSSE(w, "done", map[string]bool{"ok": true})
					return nil
				}
			}
		}
	}
}

type adminChatStreamReq struct {
	Model         string  `json:"model"`
	Temperature   float64 `json:"temperature"`
	TopP          float64 `json:"top_p"`
	RepeatPenalty float64 `json:"repeat_penalty"`
	MaxTokens     int     `json:"max_tokens"`
	Messages      []struct {
		Role    string `json:"role"`
		Content string `json:"content"`
	} `json:"messages"`
}

func streamMoeInferenceChat(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		w := ctx.Response()
		r := ctx.Request()
		if admin == nil {
			_ = apicomm.WriteSSE(w, "error", map[string]any{"message": "MoeAdmin unavailable"})
			return nil
		}
		raw, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
		if err != nil {
			_ = apicomm.WriteSSE(w, "error", map[string]any{"message": "读取请求体失败"})
			return nil
		}
		var req adminChatStreamReq
		if err := json.Unmarshal(raw, &req); err != nil {
			_ = apicomm.WriteSSE(w, "error", map[string]any{"message": "无效的 JSON 请求体"})
			return nil
		}
		messages := make([]llminference.Message, 0, len(req.Messages))
		for _, m := range req.Messages {
			role := strings.TrimSpace(m.Role)
			content := strings.TrimSpace(m.Content)
			if content == "" {
				continue
			}
			if role == "" {
				role = "user"
			}
			messages = append(messages, llminference.Message{Role: role, Content: content})
		}
		if len(messages) == 0 {
			_ = apicomm.WriteSSE(w, "error", map[string]any{"message": "消息内容不能为空"})
			return nil
		}

		cfg := conf.Inference()
		if !cfg.Ready() {
			_ = apicomm.WriteSSE(w, "error", map[string]any{"message": "llm_inference.base_url 未配置"})
			return nil
		}
		modelName := strings.TrimSpace(req.Model)
		if modelName == "" {
			deps := runtime.Deps{Inference: cfg}
			modelName = runtime.ConfiguredPostModel(deps, model.MoeAgentRuntime{})
		}
		opts := llminference.ChatOptions{
			Temperature:   req.Temperature,
			TopP:          req.TopP,
			RepeatPenalty: req.RepeatPenalty,
			MaxTokens:     req.MaxTokens,
		}

		apicomm.InitSSEHeaders(w)
		w.WriteHeader(http.StatusOK)

		started := time.Now()
		sentChunks := 0
		full, streamErr := llminference.ChatStream(r.Context(), cfg, modelName, messages, opts, func(chunk string) error {
			sentChunks++
			return apicomm.WriteSSE(w, "chunk", map[string]any{"delta": chunk})
		})
		if streamErr != nil && sentChunks == 0 && cfg.APIStyle != llminference.APIOllama {
			ollamaCfg := cfg
			base := strings.TrimRight(strings.TrimSpace(ollamaCfg.BaseURL), "/")
			if strings.HasSuffix(base, "/v1") {
				base = strings.TrimSuffix(base, "/v1")
			}
			ollamaCfg.BaseURL = base
			ollamaCfg.APIStyle = llminference.APIOllama
			if fallbackFull, fallbackErr := llminference.ChatStream(r.Context(), ollamaCfg, modelName, messages, opts, func(chunk string) error {
				sentChunks++
				return apicomm.WriteSSE(w, "chunk", map[string]any{"delta": chunk})
			}); fallbackErr == nil {
				full = fallbackFull
				streamErr = nil
			}
		}
		if streamErr != nil {
			_ = apicomm.WriteSSE(w, "error", map[string]any{
				"message": streamErr.Error(),
				"partial": full,
			})
			return nil
		}
		_ = apicomm.WriteSSE(w, "done", map[string]any{
			"ok":          true,
			"model":       modelName,
			"content":     full,
			"duration_ms": time.Since(started).Milliseconds(),
		})
		return nil
	}
}
