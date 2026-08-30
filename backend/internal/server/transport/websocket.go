package transport

import (
	"net/http"
	"strconv"

	battlev1 "backend/api/battle/v1"
	chatbiz "backend/internal/biz/chat"
	gamenetwork "backend/internal/biz/game_network"
	apicomm "backend/internal/platform/apicomm"
	battleapp "backend/internal/service/battle"
	companionapp "backend/internal/service/companion"
	lifeapp "backend/internal/service/life"

	kerrors "github.com/go-kratos/kratos/v2/errors"
	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/gorilla/websocket"
)

var battleWSUpgrader = websocket.Upgrader{CheckOrigin: func(*http.Request) bool { return true }}

func registerWebSocket(r *khttp.Router, deps Deps) {
	r.GET("/ws/chat", chatWSHandler(deps.ChatWS))
	r.GET("/ws/presence", chatPresenceWSHandler())
	r.GET("/ws/remote", chatRemoteWS())
	r.GET("/ws/game-network", gameNetworkWS())
	r.GET("/ws/world", chatWorldWSHandler())
	r.GET("/ws/admin/moe/brain/pipeline", brainPipelineWSHandler(deps.MoeAdmin))
	r.GET("/ws/life", lifeWSHandler(deps.LifeApp))
	r.GET("/ws/companion", companionWSHandler(deps.CompanionApp))
	r.GET("/ws/battle", battleWSHandler(deps.BattleApp))
}

func battleWSHandler(app *battleapp.AppService) func(khttp.Context) error {
	return func(kctx khttp.Context) error {
		if app == nil || app.Hub() == nil {
			kctx.Response().WriteHeader(501)
			return nil
		}
		userID, err := apicomm.UserIDUint(kctx.Request().Context())
		if err != nil || userID == 0 {
			return kerrors.Unauthorized("UNAUTHORIZED", "请先登录")
		}
		roomID, err := strconv.ParseUint(kctx.Request().URL.Query().Get("room_id"), 10, 64)
		if err != nil || roomID == 0 {
			return kerrors.BadRequest("INVALID_ROOM", "无效 PK 房间")
		}
		reply, err := app.GetRoom(kctx.Request().Context(), &battlev1.GetRoomRequest{RoomId: roomID})
		if err != nil {
			return err
		}
		conn, err := battleWSUpgrader.Upgrade(kctx.Response(), kctx.Request(), nil)
		if err != nil {
			return err
		}
		app.Hub().Serve(conn, uint(roomID), reply.GetRoom())
		return nil
	}
}

func chatRemoteWS() func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		chatbiz.ServeRemoteWS(ctx.Response(), ctx.Request())
		return nil
	}
}

func gameNetworkWS() func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		gamenetwork.ServeWS(ctx.Response(), ctx.Request())
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
		userID, err := apicomm.UserIDUint(kctx.Request().Context())
		if err != nil || userID == 0 {
			return kerrors.Unauthorized("UNAUTHORIZED", "请先登录")
		}
		app.Hub().ServeHTTP(kctx.Response(), kctx.Request(), userID)
		return nil
	}
}
