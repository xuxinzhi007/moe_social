package companionhttp

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strings"

	aibiz "backend/internal/biz/ai"
	apicomm "backend/internal/platform/apicomm"
	companionapp "backend/internal/service/companion"

	kerrors "github.com/go-kratos/kratos/v2/errors"
	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

type chatStreamRequest struct {
	Message   string `json:"message"`
	Scene     string `json:"scene"`
	InputMode string `json:"input_mode"`
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

	apicomm.InitSSEHeaders(w)
	if err := apicomm.WriteSSE(w, "start", map[string]string{}); err != nil {
		return fmt.Errorf("write companion chat start: %w", err)
	}

	fullReply, err := app.ChatStreamWithInputMode(r.Context(), userID, req.Message, override, req.Scene, req.InputMode, func(chunk string) error {
		return apicomm.WriteSSE(w, "delta", map[string]string{"text": chunk})
	})
	if err != nil {
		if strings.TrimSpace(fullReply) != "" {
			log.Printf("[companion] chat reply generated but history persistence failed user=%d: %v", userID, err)
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
