package moehttp

import (
	"backend/api/internal/svc"
	chatbiz "backend/internal/biz/chat"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

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
	deps := chatbiz.ChatWSDeps{
		Delivery: chatbiz.DeliveryDeps{UserReader: svcCtx.UserGW, NotifyRPC: svcCtx.UserGW},
	}
	if svcCtx != nil {
		deps.PM = svcCtx.ChatGW
		if svcCtx.UserApp != nil {
			deps.Delivery.DB = svcCtx.UserApp.DB()
		}
	}
	return deps
}
