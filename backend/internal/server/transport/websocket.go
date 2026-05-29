package transport

import (
	chatbiz "backend/internal/biz/chat"
	"backend/internal/platform/chatdelivery"
	"backend/internal/platform/svc"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func registerWebSocket(r *khttp.Router, svcCtx *svc.ServiceContext) {
	r.GET("/ws/chat", chatWSHandler(svcCtx))
	r.GET("/ws/presence", chatPresenceWSHandler())
	r.GET("/ws/remote", chatRemoteWS())
	r.GET("/ws/world", chatWorldWSHandler())
	r.GET("/ws/admin/moe/brain/pipeline", brainPipelineWSHandler(svcCtx.MoeAdmin))
}

func chatRemoteWS() func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		chatbiz.ServeRemoteWS(ctx.Response(), ctx.Request())
		return nil
	}
}

func chatWSHandler(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	deps := chatWSDeps(svcCtx)
	return func(kctx khttp.Context) error {
		chatbiz.ServeChatWS(kctx.Response(), kctx.Request(), kctx.Request().Context(), deps)
		return nil
	}
}

func chatPresenceWSHandler() func(khttp.Context) error {
	return func(kctx khttp.Context) error {
		chatbiz.ServePresenceWS(kctx.Response(), kctx.Request())
		return nil
	}
}

func chatWorldWSHandler() func(khttp.Context) error {
	return func(kctx khttp.Context) error {
		chatbiz.ServeWorldWS(kctx.Response(), kctx.Request())
		return nil
	}
}

func chatWSDeps(svcCtx *svc.ServiceContext) chatbiz.ChatWSDeps {
	return chatdelivery.ChatWSDepsFrom(svcCtx)
}
