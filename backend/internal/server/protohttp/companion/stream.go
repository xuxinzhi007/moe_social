package companionhttp

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync/atomic"
	"time"

	aibiz "backend/internal/biz/ai"
	companionbiz "backend/internal/biz/companion"
	apicomm "backend/internal/platform/apicomm"
	"backend/internal/platform/moelog"
	companionapp "backend/internal/service/companion"

	kerrors "github.com/go-kratos/kratos/v2/errors"
	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

type chatStreamRequest struct {
	Message   string `json:"message"`
	Scene     string `json:"scene"`
	InputMode string `json:"input_mode"`
	Think     bool   `json:"think"`
}

const maxChatStreamBodyBytes = 32 << 10

// RegisterChatStreamRoute 注册伙伴聊天 SSE 流式端点。
func RegisterChatStreamRoute(s *khttp.Server, app *companionapp.AppService) {
	if s == nil || app == nil {
		return
	}
	r := s.Route("/")
	r.POST("/api/companion/chat/stream", func(ctx khttp.Context) error {
		return handleChatStream(ctx, app)
	})
	r.GET("/api/companion/chat/context", func(ctx khttp.Context) error {
		return handleChatContext(ctx, app)
	})
}

func rootCause(err error) string {
	if err == nil {
		return ""
	}
	for {
		next := errors.Unwrap(err)
		if next == nil {
			return err.Error()
		}
		err = next
	}
}

func handleChatContext(ctx khttp.Context, app *companionapp.AppService) error {
	userID, err := actorUserID(ctx.Request().Context())
	if err != nil {
		return err
	}
	usage, err := app.ChatContext(ctx.Request().Context(), userID)
	if err != nil {
		return err
	}
	return ctx.Result(http.StatusOK, usage)
}

func handleChatStream(ctx khttp.Context, app *companionapp.AppService) error {
	w := ctx.Response()
	r := ctx.Request()
	userID, err := actorUserID(r.Context())
	if err != nil {
		return err
	}

	var req chatStreamRequest
	r.Body = http.MaxBytesReader(w, r.Body, maxChatStreamBodyBytes)
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		return kerrors.BadRequest("INVALID_REQUEST", "请求格式无效")
	}
	if strings.TrimSpace(req.Message) == "" {
		return kerrors.BadRequest("MESSAGE_REQUIRED", "消息不能为空")
	}
	override, err := app.ResolveChatInference(r.Context(), userID)
	if err != nil {
		if errors.Is(err, aibiz.ErrActiveProviderUnavailable) {
			return kerrors.BadRequest("INVALID_PROVIDER_CONFIG", "已保存的模型配置缺少地址或模型")
		}
		return err
	}

	modelName := ""
	if override != nil {
		modelName = override.DefaultModel
	}
	started := time.Now()
	moelog.Infof("companion chat request user=%d think=%t model=%s", userID, req.Think, modelName)
	var thinkingN, answerN atomic.Int64
	stopWait := make(chan struct{})
	defer close(stopWait)
	go func() {
		ticker := time.NewTicker(15 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-stopWait:
				return
			case <-r.Context().Done():
				return
			case <-ticker.C:
				if thinkingN.Load() == 0 && answerN.Load() == 0 {
					moelog.Infof("companion chat waiting model user=%d elapsed=%s", userID, time.Since(started).Round(time.Second))
				}
			}
		}
	}()

	apicomm.InitSSEHeaders(w)
	if err := apicomm.WriteSSE(w, "start", map[string]string{}); err != nil {
		return fmt.Errorf("write companion chat start: %w", err)
	}

	var streamCtx = r.Context()
	if req.Think {
		streamCtx = companionbiz.WithChatThink(streamCtx, true)
		streamCtx = companionbiz.WithThinkingHandler(streamCtx, func(chunk string) error {
			if thinkingN.Load() == 0 {
				moelog.Infof("companion chat thinking user=%d elapsed=%s", userID, time.Since(started).Round(time.Millisecond))
			}
			thinkingN.Add(int64(len(chunk)))
			return apicomm.WriteSSE(w, "thinking", map[string]string{"text": chunk})
		})
	}
	fullReply, err := app.ChatStreamWithInputMode(streamCtx, userID, req.Message, override, req.Scene, req.InputMode, func(chunk string) error {
		if answerN.Load() == 0 && chunk != "" {
			moelog.Infof("companion chat answer user=%d elapsed=%s", userID, time.Since(started).Round(time.Millisecond))
		}
		answerN.Add(int64(len(chunk)))
		return apicomm.WriteSSE(w, "delta", map[string]string{"text": chunk})
	})
	moelog.Infof("companion chat result user=%d think=%t thinking_bytes=%d answer_bytes=%d elapsed=%s err=%v cause=%s", userID, req.Think, thinkingN.Load(), answerN.Load(), time.Since(started).Round(time.Millisecond), err, rootCause(err))
	if err != nil {
		if strings.TrimSpace(fullReply) != "" {
			moelog.Errorf("companion chat history not saved user=%d err=%v", userID, err)
			payload := map[string]any{
				"text":          strings.TrimSpace(fullReply),
				"history_saved": false,
				"warning":       "回复已生成，但这轮没有保存到聊天历史中。",
			}
			if writeErr := apicomm.WriteSSE(w, "done", payload); writeErr != nil {
				return fmt.Errorf("write companion chat done with history warning: %w", writeErr)
			}
			return nil
		}
		detail := strings.TrimSpace(err.Error())
		if len(detail) > 500 {
			detail = detail[:500] + "…"
		}
		if detail == "" {
			detail = "模型服务调用失败"
		}
		if writeErr := apicomm.WriteSSE(w, "error", map[string]string{"text": detail}); writeErr != nil {
			return fmt.Errorf("write companion chat error: %w", writeErr)
		}
		return nil
	}

	if err := apicomm.WriteSSE(w, "done", map[string]string{"text": strings.TrimSpace(fullReply)}); err != nil {
		return fmt.Errorf("write companion chat done: %w", err)
	}
	return nil
}
