package moehttp

import (
	"backend/api/internal/svc"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

const PilotNativeAdminLegacyCompatRoutes = 28

func RegisterAdminLegacyCompat(srv *khttp.Server, svc *svc.ServiceContext) {
	if srv == nil || svc == nil {
		return
	}
	r := srv.Route("/")

	if app := svc.AdminApp; app != nil {
		r.PUT("/api/admin/ai/agents", adminLegacyUpdateAiAgent(svc))
		r.GET("/api/admin/me", adminLegacyMe())
		r.GET("/api/admin/media/images", adminLegacyListMediaImages(svc))
		r.DELETE("/api/admin/media/images/:filename", adminLegacyDeleteMediaImage(svc))
		r.GET("/api/admin/memories", adminLegacyListMemories(app))
		r.DELETE("/api/admin/memories/:memory_id", adminLegacyDeleteMemory(app, svc))
		r.GET("/api/admin/memories/stats", adminLegacyGetMemoryStats(app))
		r.GET("/api/admin/menus", adminLegacyListMenus(app))
		r.PUT("/api/admin/menus", adminLegacyUpsertMenu(app, svc))
		r.DELETE("/api/admin/menus/:menu_key", adminLegacyDeleteMenu(app, svc))
		r.POST("/api/admin/menus/bootstrap", adminLegacyBootstrapMenus(app, svc))
		r.GET("/api/admin/runtime-config", adminLegacyGetRuntimeConfig(app, svc))
		r.PUT("/api/admin/runtime-config", adminLegacyUpdateRuntimeConfig(app, svc))
		r.GET("/api/admin/runtime/overview", adminLegacyRuntimeOverview(app))
	}

	admin := svc.MoeAdmin
	r.DELETE("/api/admin/moe/brain/episodes/:id", adminDeleteMoeBrainEpisode(admin))
	r.POST("/api/admin/moe/brain/episodes/:id/refine", adminRefineMoeBrainEpisode(admin))
	r.GET("/api/admin/moe/brain/pipeline/stream", adminStreamMoeBrainPipeline(admin))
	r.GET("/api/admin/moe/inference/status", adminGetMoeInferenceStatus(admin, svc))
	r.GET("/api/admin/moe/runtimes/:agent_key/brain", adminGetMoeBrain(admin))
	r.POST("/api/admin/moe/runtimes/:agent_key/brain/curate", adminCurateMoeBrain(admin))
	r.PUT("/api/admin/moe/runtimes/:agent_key/brain/policy", adminUpdateMoeBrainPolicy(admin))
	r.GET("/api/admin/moe/runtimes/:agent_key/flow", adminGetMoeBotFlow(admin))
	r.PUT("/api/admin/moe/runtimes/:agent_key/flow", adminUpsertMoeBotFlow(admin))
	r.DELETE("/api/admin/moe/runtimes/:agent_key/flow", adminDeleteMoeBotFlow(admin))
	r.POST("/api/admin/moe/runtimes/:agent_key/run-once", adminRunMoeAgentOnce(admin))
	r.GET("/api/admin/moe/tools/calls", adminListMoeToolCalls(admin))
	r.GET("/api/admin/moe/tools/schema", adminGetMoeToolsSchema())
	r.GET("/api/admin/moe/tools/stats", adminGetMoeToolStats(admin))
}
