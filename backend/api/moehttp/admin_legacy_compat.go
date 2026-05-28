package moehttp

import (
	"backend/api/internal/svc"
	hadmin "backend/api/internal/handler/admin"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

const PilotNativeAdminLegacyCompatRoutes = 28

func RegisterAdminLegacyCompat(srv *khttp.Server, svc *svc.ServiceContext) {
	if srv == nil || svc == nil {
		return
	}
	r := srv.Route("/")
	r.PUT("/api/admin/ai/agents", wrapNativeHTTP(hadmin.AdminUpdateAiAgentHandler(svc)))
	r.GET("/api/admin/me", wrapNativeHTTP(hadmin.AdminMeHandler(svc)))
	r.GET("/api/admin/media/images", wrapNativeHTTP(hadmin.AdminListMediaImagesHandler(svc)))
	r.DELETE("/api/admin/media/images/:filename", wrapNativeHTTP(hadmin.AdminDeleteMediaImageHandler(svc)))
	r.GET("/api/admin/memories", wrapNativeHTTP(hadmin.AdminListMemoriesHandler(svc)))
	r.DELETE("/api/admin/memories/:memory_id", wrapNativeHTTP(hadmin.AdminDeleteMemoryHandler(svc)))
	r.GET("/api/admin/memories/stats", wrapNativeHTTP(hadmin.AdminGetMemoryStatsHandler(svc)))
	r.GET("/api/admin/menus", wrapNativeHTTP(hadmin.AdminListMenusHandler(svc)))
	r.PUT("/api/admin/menus", wrapNativeHTTP(hadmin.AdminUpsertMenuHandler(svc)))
	r.DELETE("/api/admin/menus/:menu_key", wrapNativeHTTP(hadmin.AdminDeleteMenuHandler(svc)))
	r.POST("/api/admin/menus/bootstrap", wrapNativeHTTP(hadmin.AdminBootstrapMenusHandler(svc)))
	r.DELETE("/api/admin/moe/brain/episodes/:id", wrapNativeHTTP(hadmin.AdminDeleteMoeBrainEpisodeHandler(svc)))
	r.POST("/api/admin/moe/brain/episodes/:id/refine", wrapNativeHTTP(hadmin.AdminRefineMoeBrainEpisodeHandler(svc)))
	r.GET("/api/admin/moe/brain/pipeline/stream", wrapNativeHTTP(hadmin.AdminStreamMoeBrainPipelineHandler(svc)))
	r.GET("/api/admin/moe/inference/status", wrapNativeHTTP(hadmin.AdminGetMoeInferenceStatusHandler(svc)))
	r.GET("/api/admin/moe/runtimes/:agent_key/brain", wrapNativeHTTP(hadmin.AdminGetMoeBrainHandler(svc)))
	r.POST("/api/admin/moe/runtimes/:agent_key/brain/curate", wrapNativeHTTP(hadmin.AdminCurateMoeBrainHandler(svc)))
	r.PUT("/api/admin/moe/runtimes/:agent_key/brain/policy", wrapNativeHTTP(hadmin.AdminUpdateMoeBrainPolicyHandler(svc)))
	r.GET("/api/admin/moe/runtimes/:agent_key/flow", wrapNativeHTTP(hadmin.AdminGetMoeBotFlowHandler(svc)))
	r.PUT("/api/admin/moe/runtimes/:agent_key/flow", wrapNativeHTTP(hadmin.AdminUpsertMoeBotFlowHandler(svc)))
	r.DELETE("/api/admin/moe/runtimes/:agent_key/flow", wrapNativeHTTP(hadmin.AdminDeleteMoeBotFlowHandler(svc)))
	r.POST("/api/admin/moe/runtimes/:agent_key/run-once", wrapNativeHTTP(hadmin.AdminRunMoeAgentOnceHandler(svc)))
	r.GET("/api/admin/moe/tools/calls", wrapNativeHTTP(hadmin.AdminListMoeToolCallsHandler(svc)))
	r.GET("/api/admin/moe/tools/schema", wrapNativeHTTP(hadmin.AdminGetMoeToolsSchemaHandler(svc)))
	r.GET("/api/admin/moe/tools/stats", wrapNativeHTTP(hadmin.AdminGetMoeToolStatsHandler(svc)))
	r.GET("/api/admin/runtime-config", wrapNativeHTTP(hadmin.AdminGetRuntimeConfigHandler(svc)))
	r.PUT("/api/admin/runtime-config", wrapNativeHTTP(hadmin.AdminUpdateRuntimeConfigHandler(svc)))
	r.GET("/api/admin/runtime/overview", wrapNativeHTTP(hadmin.AdminRuntimeOverviewHandler(svc)))
}
