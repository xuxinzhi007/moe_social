package moehttp

import (
	"backend/api/internal/svc"
	happcfg "backend/api/internal/handler/appcfg"
	hcontent "backend/api/internal/handler/content"
	hllm "backend/api/internal/handler/llm"
	hmoe "backend/api/internal/handler/moe"
	hvoice "backend/api/internal/handler/voice"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativePlatformLogicCompatRoutes 波次3：logic 薄转（待二期 internal/service）。
const PilotNativePlatformLogicCompatRoutes = 17

// RegisterPlatformLogicCompat 注册 HTTP。
func RegisterPlatformLogicCompat(srv *khttp.Server, svc *svc.ServiceContext) {
	if srv == nil || svc == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/api/public/client-config", wrapNativeHTTP(happcfg.PublicClientConfigHandler(svc)))
	r.GET("/api/user/:user_id/content", wrapNativeHTTP(hcontent.GetContentListHandler(svc)))
	r.POST("/api/llm/agents", wrapNativeHTTP(hllm.CreateAgentHandler(svc)))
	r.POST("/api/llm/chat", wrapNativeHTTP(hllm.ChatHandler(svc)))
	r.POST("/api/llm/chat/raw", wrapNativeHTTP(hllm.ChatRawHandler(svc)))
	r.GET("/api/llm/config", wrapNativeHTTP(hllm.ConfigHandler(svc)))
	r.POST("/api/llm/models/delete", wrapNativeHTTP(hllm.DeleteModelHandler(svc)))
	r.POST("/api/llm/models/download", wrapNativeHTTP(hllm.DownloadModelHandler(svc)))
	r.GET("/api/llm/models/raw", wrapNativeHTTP(hllm.ModelsRawHandler(svc)))
	r.POST("/api/llm/show/raw", wrapNativeHTTP(hllm.ShowRawHandler(svc)))
	r.POST("/api/moe/tools/execute", wrapNativeHTTP(hmoe.ExecuteMoeToolHandler(svc)))
	r.GET("/api/moe/tools/schema", wrapNativeHTTP(hmoe.GetMoeToolsSchemaHandler(svc)))
	r.POST("/api/voice/answer", wrapNativeHTTP(hvoice.VoiceAnswerHandler(svc)))
	r.POST("/api/voice/call", wrapNativeHTTP(hvoice.VoiceCallHandler(svc)))
	r.POST("/api/voice/cancel", wrapNativeHTTP(hvoice.VoiceCancelHandler(svc)))
	r.POST("/api/voice/reject", wrapNativeHTTP(hvoice.VoiceRejectHandler(svc)))
	r.GET("/api/voice/token", wrapNativeHTTP(hvoice.GetRtcTokenHandler(svc)))
}
