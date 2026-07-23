package companionhttp

import (
	"encoding/json"
	"io"
	"strings"

	"backend/internal/apilegacy/common"
	companionapp "backend/internal/service/companion"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

type chatStreamRequest struct {
	UserID  uint   `json:"user_id"`
	Message string `json:"message"`
}

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
	common.InitSSEHeaders(w)

	var req chatStreamRequest
	body, _ := io.ReadAll(r.Body)
	_ = json.Unmarshal(body, &req)
	if strings.TrimSpace(req.Message) == "" {
		_ = common.WriteSSE(w, "error", map[string]string{"message": "message required"})
		return nil
	}
	if req.UserID == 0 {
		req.UserID = 1 // TODO: 从 JWT 提取
	}

	_ = common.WriteSSE(w, "start", map[string]string{})

	engine := app.Engine()
	if engine == nil {
		_ = common.WriteSSE(w, "error", map[string]string{"message": "companion unavailable"})
		return nil
	}

	_, err := engine.ChatStream(r.Context(), req.UserID, req.Message, func(chunk string) error {
		return common.WriteSSE(w, "delta", map[string]string{"text": chunk})
	})
	if err != nil {
		_ = common.WriteSSE(w, "error", map[string]string{"message": err.Error()})
		return nil
	}

	_ = common.WriteSSE(w, "done", map[string]string{})
	return nil
}
