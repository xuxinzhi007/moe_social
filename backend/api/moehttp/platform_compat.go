package moehttp

import (
	"context"

	hcontent "backend/api/internal/handler/content"
	hllm "backend/api/internal/handler/llm"
	hmoe "backend/api/internal/handler/moe"
	hvoice "backend/api/internal/handler/voice"
	appcfglogic "backend/api/internal/logic/appcfg"
	llmlogic "backend/api/internal/logic/llm"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativePlatformCompatRoutes LLM 写 / voice / moe / appcfg（流式/WS 类仍 wrapNativeHTTP）。
const PilotNativePlatformCompatRoutes = 17

func RegisterPlatformCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/api/public/client-config", platPublicClientConfig(svcCtx))
	r.GET("/api/user/:user_id/content", wrapNativeHTTP(hcontent.GetContentListHandler(svcCtx)))
	r.POST("/api/llm/agents", platCreateAgent(svcCtx))
	r.POST("/api/llm/chat", platChat(svcCtx))
	r.POST("/api/llm/chat/raw", wrapNativeHTTP(hllm.ChatRawHandler(svcCtx)))
	r.GET("/api/llm/config", wrapNativeHTTP(hllm.ConfigHandler(svcCtx)))
	r.POST("/api/llm/models/delete", platDeleteModel(svcCtx))
	r.POST("/api/llm/models/download", platDownloadModel(svcCtx))
	r.GET("/api/llm/models/raw", wrapNativeHTTP(hllm.ModelsRawHandler(svcCtx)))
	r.POST("/api/llm/show/raw", wrapNativeHTTP(hllm.ShowRawHandler(svcCtx)))
	r.POST("/api/moe/tools/execute", wrapNativeHTTP(hmoe.ExecuteMoeToolHandler(svcCtx)))
	r.GET("/api/moe/tools/schema", wrapNativeHTTP(hmoe.GetMoeToolsSchemaHandler(svcCtx)))
	r.POST("/api/voice/answer", wrapNativeHTTP(hvoice.VoiceAnswerHandler(svcCtx)))
	r.POST("/api/voice/call", wrapNativeHTTP(hvoice.VoiceCallHandler(svcCtx)))
	r.POST("/api/voice/cancel", wrapNativeHTTP(hvoice.VoiceCancelHandler(svcCtx)))
	r.POST("/api/voice/reject", wrapNativeHTTP(hvoice.VoiceRejectHandler(svcCtx)))
	r.GET("/api/voice/token", wrapNativeHTTP(hvoice.GetRtcTokenHandler(svcCtx)))
}

func platPublicClientConfig(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.EmptyReq) (any, error) {
		l := appcfglogic.NewPublicClientConfigLogic(ctx, svcCtx)
		return l.PublicClientConfig(req)
	})
}

func platCreateAgent(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.LlmCreateAgentReq) (any, error) {
		l := llmlogic.NewCreateAgentLogic(ctx, svcCtx)
		return l.CreateAgent(req)
	})
}

func platChat(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.LlmChatReq) (any, error) {
		l := llmlogic.NewChatLogic(ctx, svcCtx)
		return l.Chat(req)
	})
}

func platDeleteModel(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.LlmDeleteModelReq) (any, error) {
		l := llmlogic.NewDeleteModelLogic(ctx, svcCtx)
		return l.DeleteModel(req)
	})
}

func platDownloadModel(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return invokeLogicJSON(svcCtx, func(ctx context.Context, svcCtx *svc.ServiceContext, req *types.LlmDownloadModelReq) (any, error) {
		l := llmlogic.NewDownloadModelLogic(ctx, svcCtx)
		return l.DownloadModel(req)
	})
}
