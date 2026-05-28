package moehttp

import (
	"backend/api/internal/svc"
	huser "backend/api/internal/handler/user"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeUserMemoryCompatRoutes 用户记忆（LLMApp；经 goctl handler/logic）。
const PilotNativeUserMemoryCompatRoutes = 8

func RegisterUserMemoryCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	r := srv.Route("/")
	r.POST("/api/user/:user_id/memories", wrapNativeHTTP(huser.UpsertUserMemoryHandler(svcCtx)))
	r.GET("/api/user/:user_id/memories", wrapNativeHTTP(huser.GetUserMemoriesHandler(svcCtx)))
	r.DELETE("/api/user/:user_id/memories", wrapNativeHTTP(huser.DeleteUserMemoryHandler(svcCtx)))
	r.GET("/api/user/:user_id/memories/display", wrapNativeHTTP(huser.GetUserMemoriesDisplayHandler(svcCtx)))
	r.POST("/api/user/:user_id/memories/feedback", wrapNativeHTTP(huser.SubmitUserMemoryFeedbackHandler(svcCtx)))
	r.GET("/api/user/:user_id/memories/profiles", wrapNativeHTTP(huser.GetUserMemoryProfilesHandler(svcCtx)))
	r.POST("/api/user/:user_id/memories/reindex", wrapNativeHTTP(huser.RebuildUserMemoryEmbeddingsHandler(svcCtx)))
	r.GET("/api/user/:user_id/memories/search", wrapNativeHTTP(huser.SearchUserMemoriesHandler(svcCtx)))
}
