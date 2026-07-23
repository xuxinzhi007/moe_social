package companionhttp

import (
	"encoding/json"
	"net/http"
	"strings"

	"backend/internal/apilegacy/common"
	companionapp "backend/internal/service/companion"

	kerrors "github.com/go-kratos/kratos/v2/errors"
	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

type chatStreamRequest struct {
	Message string `json:"message"`
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

	common.InitSSEHeaders(w)
	_ = common.WriteSSE(w, "start", map[string]string{})

	_, err = app.ChatStream(r.Context(), userID, req.Message, func(chunk string) error {
		return common.WriteSSE(w, "delta", map[string]string{"text": chunk})
	})
	if err != nil {
		_ = common.WriteSSE(w, "error", map[string]string{"message": err.Error()})
		return nil
	}

	_ = common.WriteSSE(w, "done", map[string]string{})
	return nil
}
