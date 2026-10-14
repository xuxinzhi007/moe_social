package companionhttp

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	aibiz "backend/internal/biz/ai"
	companionapp "backend/internal/service/companion"

	kerrors "github.com/go-kratos/kratos/v2/errors"
	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

type heroChatRequest struct {
	HeroSlug string `json:"hero_slug"`
	Message  string `json:"message"`
}

// RegisterHeroChatRoute 注册 K3 小家闲聊端点（M1 非流式 JSON）。
func RegisterHeroChatRoute(s *khttp.Server, app *companionapp.AppService) {
	if s == nil || app == nil {
		return
	}
	r := s.Route("/")
	r.POST("/api/companion/hero/chat", func(ctx khttp.Context) error {
		return handleHeroChat(ctx, app)
	})
}

func handleHeroChat(ctx khttp.Context, app *companionapp.AppService) error {
	w := ctx.Response()
	r := ctx.Request()
	userID, err := actorUserID(r.Context())
	if err != nil {
		return err
	}

	var req heroChatRequest
	r.Body = http.MaxBytesReader(w, r.Body, maxChatStreamBodyBytes)
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		return kerrors.BadRequest("INVALID_REQUEST", "请求格式无效")
	}
	if strings.TrimSpace(req.HeroSlug) == "" {
		return kerrors.BadRequest("HERO_REQUIRED", "缺少英雄标识")
	}
	override, err := app.ResolveChatInference(r.Context(), userID)
	if err != nil {
		if errors.Is(err, aibiz.ErrActiveProviderUnavailable) {
			return kerrors.BadRequest("INVALID_PROVIDER_CONFIG", "已保存的模型配置缺少地址或模型")
		}
		return err
	}

	reply, err := app.HeroChat(r.Context(), userID, strings.TrimSpace(req.HeroSlug), req.Message, override)
	if err != nil {
		return err
	}
	return ctx.Result(http.StatusOK, map[string]string{"reply": reply})
}
