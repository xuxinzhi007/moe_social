package moehttp

import (
	"context"
	"errors"
	"net/http"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	userv1 "backend/api/user/v1"
	contentbiz "backend/internal/biz/content"
	llmbiz "backend/internal/biz/llm"
	moebiz "backend/internal/biz/moe"
	voicebiz "backend/internal/biz/voice"
	appcfgapp "backend/internal/service/appcfg"
	contentapp "backend/internal/service/content"
	llmapp "backend/internal/service/llm"
	moeadmin "backend/internal/service/moe"
	voiceapp "backend/internal/service/voice"
	"backend/pkg/llminference"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativePlatformCompatRoutes LLM 读/写 / voice / moe / appcfg（全部 tier-A）。
const PilotNativePlatformCompatRoutes = 17

func RegisterPlatformCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	contentApp := contentapp.New()
	moePlatform := moeadmin.NewPlatform(newPlatformMoeToolExecutor(svcCtx))
	voiceApp := voiceapp.New(newVoiceUserResolver(svcCtx), voicebiz.AgoraConfig{
		AppID:          svcCtx.Config.Agora.AppId,
		AppCertificate: svcCtx.Config.Agora.AppCertificate,
	})

	r := srv.Route("/")
	r.GET("/api/public/client-config", platPublicClientConfig(svcCtx))
	r.GET("/api/user/:user_id/content", platGetContentList(contentApp))
	r.POST("/api/llm/chat/raw", platChatRaw(svcCtx))
	r.GET("/api/llm/config", platLLMConfig(svcCtx))
	r.GET("/api/llm/models/raw", platModelsRaw(svcCtx))
	r.POST("/api/llm/show/raw", platShowRaw(svcCtx))
	r.POST("/api/moe/tools/execute", platMoeExecuteTool(moePlatform))
	r.GET("/api/moe/tools/schema", platMoeToolsSchema(moePlatform))
	r.POST("/api/voice/answer", platVoiceAnswer(voiceApp))
	r.POST("/api/voice/call", platVoiceCall(voiceApp))
	r.POST("/api/voice/cancel", platVoiceCancel(voiceApp))
	r.POST("/api/voice/reject", platVoiceReject(voiceApp))
	r.GET("/api/voice/token", platVoiceToken(voiceApp))

	if svcCtx.LLMApp == nil {
		return
	}
	app := svcCtx.LLMApp
	r.POST("/api/llm/agents", platCreateAgent(app, svcCtx))
	r.POST("/api/llm/chat", platChat(app, svcCtx))
	r.POST("/api/llm/models/delete", platDeleteModel(app, svcCtx))
	r.POST("/api/llm/models/download", platDownloadModel(app, svcCtx))
}

func platMoeToolsSchema(app *moeadmin.PlatformApp) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		result := app.ToolsSchema()
		return ctx.JSON(http.StatusOK, types.MoeToolSchemaResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data: types.MoeToolSchemaData{
				Tools: result.Tools,
				Tier:  result.Tier,
			},
		})
	}
}

func platMoeExecuteTool(app *moeadmin.PlatformApp) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.MoeToolExecuteReq
		if err := bindRequest(ctx, &req); err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		actorUID, err := moeBearerUserID(ctx)
		if err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		result, execErr := app.ExecuteTool(ctx, moebiz.ExecuteToolInput{
			Tool:           req.Tool,
			ArgumentsJSON:  req.Arguments,
			ActorUserID:    actorUID,
			AgentKey:       req.AgentKey,
			Source:         "api",
			IdempotencyKey: req.IdempotencyKey,
		})
		if execErr != nil {
			return ctx.JSON(http.StatusOK, types.MoeToolExecuteResp{
				BaseResp: common.HandleRPCError(execErr, ""),
			})
		}
		return ctx.JSON(http.StatusOK, types.MoeToolExecuteResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data: types.MoeToolExecuteData{
				Ok:     result.OK,
				Result: result.Result,
				Error:  result.Error,
			},
		})
	}
}

func platVoiceCall(app *voiceapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.VoiceCallReq
		if err := bindRequest(ctx, &req); err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		callerID, err := jwtUserIDString(ctx)
		if err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		result, err := app.VoiceCall(ctx, callerID, req.ReceiverId)
		if err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		return ctx.JSON(http.StatusOK, types.VoiceCallResp{
			BaseResp: types.BaseResp{Code: 0, Message: "success", Success: true},
			Data: types.VoiceCallData{
				CallId:      result.CallID,
				ChannelName: result.ChannelName,
			},
		})
	}
}

func platVoiceAnswer(app *voiceapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.VoiceAnswerReq
		if err := bindRequest(ctx, &req); err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		userID, err := jwtUserIDString(ctx)
		if err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		result, err := app.VoiceAnswer(ctx, userID, req.CallId)
		if err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		return ctx.JSON(http.StatusOK, types.VoiceAnswerResp{
			BaseResp: types.BaseResp{Code: 0, Message: "success", Success: true},
			Data:     types.VoiceAnswerData{ChannelName: result.ChannelName},
		})
	}
}

func platVoiceCancel(app *voiceapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.VoiceCancelReq
		if err := bindRequest(ctx, &req); err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		callerID, err := jwtUserIDString(ctx)
		if err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		if err := app.VoiceCancel(ctx, callerID, req.CallId); err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		return ctx.JSON(http.StatusOK, types.BaseResp{Code: 0, Message: "success", Success: true})
	}
}

func platVoiceReject(app *voiceapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.VoiceRejectReq
		if err := bindRequest(ctx, &req); err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		userID, err := jwtUserIDString(ctx)
		if err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		if err := app.VoiceReject(ctx, userID, req.CallId); err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		return ctx.JSON(http.StatusOK, types.BaseResp{Code: 0, Message: "success", Success: true})
	}
}

func platVoiceToken(app *voiceapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetRtcTokenReq
		if err := bindRequest(ctx, &req); err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		userAccount := strings.TrimSpace(req.UserAccount)
		if userAccount == "" {
			var err error
			userAccount, err = jwtUserIDString(ctx)
			if err != nil {
				http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
				return nil
			}
		}
		result, err := app.GetRtcToken(ctx, voicebiz.TokenInput{
			ChannelName: req.ChannelName,
			UserAccount: userAccount,
			Role:        req.Role,
		})
		if err != nil {
			http.Error(ctx.Response(), err.Error(), http.StatusBadRequest)
			return nil
		}
		return ctx.JSON(http.StatusOK, types.GetRtcTokenResp{
			BaseResp: types.BaseResp{Code: 0, Message: "success", Success: true},
			Token:    result.Token,
			AppId:    result.AppID,
		})
	}
}

type platformMoeToolExecutor struct {
	svcCtx *svc.ServiceContext
}

func newPlatformMoeToolExecutor(svcCtx *svc.ServiceContext) moeadmin.ToolExecutor {
	return &platformMoeToolExecutor{svcCtx: svcCtx}
}

func (e *platformMoeToolExecutor) ExecuteTool(ctx context.Context, in moebiz.ExecuteToolInput) (moebiz.ExecuteToolResult, error) {
	if e == nil || e.svcCtx == nil || e.svcCtx.MoeAdmin == nil {
		return moebiz.ExecuteToolResult{}, errors.New("moe backend unavailable")
	}
	return e.svcCtx.MoeAdmin.ExecuteTool(ctx, in)
}

type voiceUserResolver struct {
	svcCtx *svc.ServiceContext
}

func newVoiceUserResolver(svcCtx *svc.ServiceContext) voicebiz.UserDisplayResolver {
	return &voiceUserResolver{svcCtx: svcCtx}
}

func (r *voiceUserResolver) ResolveVoiceUserDisplay(ctx context.Context, userID string) (displayName, avatar string) {
	displayName = "用户"
	avatar = ""
	if r == nil || r.svcCtx == nil || r.svcCtx.UserApp == nil {
		return displayName, avatar
	}
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return displayName, avatar
	}
	resp, err := r.svcCtx.UserApp.GetUser(ctx, &userv1.GetUserReq{UserId: userID})
	if err != nil || resp == nil || resp.GetUser() == nil {
		return displayName, avatar
	}
	u := resp.GetUser()
	if n := strings.TrimSpace(u.GetUsername()); n != "" {
		displayName = n
	}
	avatar = strings.TrimSpace(u.GetAvatar())
	return displayName, avatar
}

func moeBearerUserID(ctx khttp.Context) (uint, error) {
	authHeader := ctx.Request().Header.Get("Authorization")
	if !strings.HasPrefix(authHeader, "Bearer ") {
		return 0, errors.New("missing or invalid authorization header")
	}
	tokenString := strings.TrimPrefix(authHeader, "Bearer ")
	return utils.GetUserIDFromToken(tokenString)
}

func platPublicClientConfig(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	app := appcfgapp.New(svcCtx.Config.ClientPublicApiBaseUrl)
	return func(ctx khttp.Context) error {
		url, err := app.PublicClientConfig()
		if err != nil {
			if errors.Is(err, appcfgapp.ErrNoPublicAPIBaseURL) {
				return ctx.Result(http.StatusNotFound, nil)
			}
			return err
		}
		return ctx.JSON(http.StatusOK, types.PublicClientConfigResp{ApiBaseUrl: url})
	}
}

func platGetContentList(app *contentapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.ContentListReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		result := app.ListContent(ctx, contentbiz.ListInput{
			UserID: req.UserId, Type: req.Type, Page: req.Page, PageSize: req.PageSize,
		})
		items := make([]types.ContentItem, 0, len(result.Items))
		for _, item := range result.Items {
			items = append(items, types.ContentItem{
				Id: item.ID, UserId: item.UserID, Type: item.Type, Prompt: item.Prompt,
				Url: item.URL, Content: item.Content, CreatedAt: item.CreatedAt,
			})
		}
		return ctx.JSON(http.StatusOK, types.ContentListResp{
			BaseResp: types.BaseResp{Code: 200, Message: "获取内容列表成功", Success: true},
			Data:     items,
			Total:    result.Total,
		})
	}
}

func platLLMConfig(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var data map[string]interface{}
		if svcCtx.LLMApp != nil {
			data = svcCtx.LLMApp.ConfigAPIPayload()
		} else {
			data = llmbiz.ConfigAPIPayload(platformConfigSnapshotFromSvc(svcCtx))
		}
		return ctx.JSON(http.StatusOK, map[string]interface{}{
			"code":    200,
			"message": "获取 LLM 配置成功",
			"success": true,
			"data":    data,
		})
	}
}

func platChatRaw(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		w, r := ctx.Response(), ctx.Request()
		if svcCtx.LLMApp != nil {
			return svcCtx.LLMApp.ForwardChatRaw(w, r)
		}
		cfg := platformInferenceCfgFromSvc(svcCtx)
		return llmbiz.ForwardChatRaw(w, r, cfg)
	}
}

func platModelsRaw(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		w, r := ctx.Response(), ctx.Request()
		if svcCtx.LLMApp != nil {
			return svcCtx.LLMApp.ForwardModelsRaw(w, r)
		}
		cfg := platformInferenceCfgFromSvc(svcCtx)
		return llmbiz.ForwardModelsRaw(w, r, cfg)
	}
}

func platShowRaw(svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		w, r := ctx.Response(), ctx.Request()
		if svcCtx.LLMApp != nil {
			return svcCtx.LLMApp.ForwardShowRaw(w, r)
		}
		cfg := platformInferenceCfgFromSvc(svcCtx)
		return llmbiz.ForwardShowRaw(w, r, cfg)
	}
}

func platformInferenceCfgFromSvc(svcCtx *svc.ServiceContext) llminference.Config {
	if svcCtx == nil {
		return llminference.Config{}
	}
	c := svcCtx.Config.LLMInference
	return llminference.ConfigFrom(c.BaseUrl, c.ApiStyle, c.TimeoutSeconds, c.MemoryModel)
}

func platformConfigSnapshotFromSvc(svcCtx *svc.ServiceContext) llmbiz.ConfigSnapshot {
	if svcCtx == nil {
		return llmbiz.ConfigSnapshot{MemoryBudget: llmbiz.DefaultMemoryBudget()}
	}
	c := svcCtx.Config
	inf := c.LLMInference
	return llmbiz.ConfigSnapshot{
		InferenceBaseURL:       inf.BaseUrl,
		InferenceAPIStyle:      inf.ApiStyle,
		InferenceTimeoutSec:    inf.TimeoutSeconds,
		MemoryModel:            inf.MemoryModel,
		HasSummaryPrompt:       inf.MemorySummaryPrompt != "",
		HasExtractPrompt:       inf.MemoryExtractPrompt != "",
		LocalModelsStorageDir:  c.LocalModels.StorageDir,
		LocalModelsCatalogSize: len(c.LocalModels.Catalog),
		MemoryBudget:           llmbiz.DefaultMemoryBudget(),
	}
}

func platCreateAgent(app *llmapp.AppService, svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.LlmCreateAgentReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		result := app.CreateAgent(ctx, llmbiz.CreateAgentInput{
			Name: req.Name, BaseModel: req.BaseModel, SystemPrompt: req.SystemPrompt,
		}, svcCtx.ModelCache)
		return ctx.JSON(http.StatusOK, platformWriteToBaseResp(result))
	}
}

func platChat(app *llmapp.AppService, svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.LlmChatReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		outcome, err := app.Chat(ctx, platformChatInputFromReq(&req))
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, types.LlmChatResp{
			BaseResp: types.BaseResp{
				Code: outcome.Code, Message: outcome.Message, Success: outcome.Success,
			},
			Content: outcome.Content, RemainingRatio: outcome.RemainingRatio, Summarized: outcome.Summarized,
		})
	}
}

func platDeleteModel(app *llmapp.AppService, svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.LlmDeleteModelReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		result := app.DeleteModel(ctx, req.Model, svcCtx.ModelCache)
		return ctx.JSON(http.StatusOK, platformWriteToBaseResp(result))
	}
}

func platDownloadModel(app *llmapp.AppService, svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.LlmDownloadModelReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		result := app.DownloadModel(ctx, req.Model, svcCtx.ModelCache)
		return ctx.JSON(http.StatusOK, platformWriteToBaseResp(result))
	}
}

func platformChatInputFromReq(req *types.LlmChatReq) llmbiz.PlatformChatInput {
	in := llmbiz.PlatformChatInput{
		Model: req.Model, SessionId: req.SessionId, SourceMsgId: req.SourceMsgId,
		ClientMemoryApplied: req.ClientMemoryApplied, Stream: req.Stream,
		Temperature: req.Temperature, TopP: req.TopP, MaxTokens: req.MaxTokens,
		RepeatPenalty: req.RepeatPenalty,
	}
	if len(req.Messages) > 0 {
		in.Messages = make([]llmbiz.PlatformChatMessage, len(req.Messages))
		for i, m := range req.Messages {
			in.Messages[i] = llmbiz.PlatformChatMessage{Role: m.Role, Content: m.Content}
		}
	}
	return in
}

func platformWriteToBaseResp(result llmbiz.PlatformWriteResult) types.BaseResp {
	return types.BaseResp{Code: result.Code, Message: result.Message, Success: result.Success}
}
