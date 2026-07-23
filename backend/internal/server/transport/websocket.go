package transport

import (
	"backend/internal/apilegacy/common"
	chatbiz "backend/internal/biz/chat"
	companionapp "backend/internal/service/companion"
	lifeapp "backend/internal/service/life"

	kerrors "github.com/go-kratos/kratos/v2/errors"
	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func registerWebSocket(r *khttp.Router, deps Deps) {
	r.GET("/ws/chat", chatWSHandler(deps.ChatWS))
	r.GET("/ws/presence", chatPresenceWSHandler())
	r.GET("/ws/remote", chatRemoteWS())
	r.GET("/ws/world", chatWorldWSHandler())
	r.GET("/ws/admin/moe/brain/pipeline", brainPipelineWSHandler(deps.MoeAdmin))
	r.GET("/ws/life", lifeWSHandler(deps.LifeApp))
	r.GET("/ws/companion", companionWSHandler(deps.CompanionApp))
}

func chatRemoteWS() func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		chatbiz.ServeRemoteWS(ctx.Response(), ctx.Request())
		return nil
	}
}

func chatWSHandler(deps chatbiz.ChatWSDeps) func(khttp.Context) error {
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

func lifeWSHandler(app *lifeapp.AppService) func(khttp.Context) error {
	return func(kctx khttp.Context) error {
		if app == nil || app.Hub() == nil {
			kctx.Response().WriteHeader(501)
			return nil
		}
		app.Hub().ServeHTTP(kctx.Response(), kctx.Request())
		return nil
	}
}

func companionWSHandler(app *companionapp.AppService) func(khttp.Context) error {
	return func(kctx khttp.Context) error {
		if app == nil || app.Hub() == nil {
			kctx.Response().WriteHeader(501)
			return nil
		}
		userID, err := common.UserIDUint(kctx.Request().Context())
		if err != nil || userID == 0 {
			return kerrors.Unauthorized("UNAUTHORIZED", "请先登录")
		}
		app.Hub().ServeHTTP(kctx.Response(), kctx.Request(), userID)
		return nil
	}
}
