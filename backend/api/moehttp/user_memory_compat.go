package moehttp

import (
	"errors"
	"net/http"
	"strconv"

	userbiz "backend/internal/biz/user"
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	llmapp "backend/internal/service/llm"
	"backend/rpc/pb/moe"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeUserMemoryCompatRoutes 用户记忆（LLMApp tier-A）。
const PilotNativeUserMemoryCompatRoutes = 8

func RegisterUserMemoryCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil || svcCtx.LLMApp == nil {
		return
	}
	app := svcCtx.LLMApp
	r := srv.Route("/")
	r.POST("/api/user/:user_id/memories", upsertUserMemory(app))
	r.GET("/api/user/:user_id/memories", getUserMemories(app))
	r.DELETE("/api/user/:user_id/memories", deleteUserMemory(app))
	r.GET("/api/user/:user_id/memories/display", getUserMemoriesDisplay(app))
	r.POST("/api/user/:user_id/memories/feedback", submitUserMemoryFeedback(app))
	r.GET("/api/user/:user_id/memories/profiles", getUserMemoryProfiles(app))
	r.POST("/api/user/:user_id/memories/reindex", rebuildUserMemoryEmbeddings(app))
	r.GET("/api/user/:user_id/memories/search", searchUserMemories(svcCtx, app))
}

func upsertUserMemory(app *llmapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.UpsertUserMemoryReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.UpsertUserMemoryResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.UpsertUserMemory(ctx, &moe.UpsertUserMemoryReq{
			UserId: req.UserId, Key: req.Key, Value: req.Value, MemoryType: req.MemoryType,
			Confidence: req.Confidence, Source: req.Source, SourceMsgId: req.SourceMsgId, SessionId: req.SessionId,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.UpsertUserMemoryResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.UpsertUserMemoryResp{
			BaseResp: common.HandleRPCError(nil, "更新用户记忆成功"),
			Data:     userMemoryFromRPC(rpcResp.Memory),
		})
	}
}

func getUserMemories(app *llmapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUserMemoriesReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUserMemoriesResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetUserMemories(ctx, &moe.GetUserMemoriesReq{
			UserId: req.UserId, Limit: int32(req.Limit), Offset: int32(req.Offset),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUserMemoriesResp{BaseResp: common.HandleRPCError(err, "")})
		}
		memories := make([]types.UserMemory, 0, len(rpcResp.Memories))
		for _, m := range rpcResp.Memories {
			memories = append(memories, userMemoryFromRPC(m))
		}
		return ctx.JSON(http.StatusOK, types.GetUserMemoriesResp{
			BaseResp: common.HandleRPCError(nil, "获取用户记忆成功"),
			Data: memories, Total: rpcResp.Total, Limit: int(rpcResp.Limit),
			Offset: int(rpcResp.Offset), HasMore: rpcResp.HasMore,
		})
	}
}

func deleteUserMemory(app *llmapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.DeleteUserMemoryReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.DeleteUserMemoryResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		_, err := app.DeleteUserMemory(ctx, &moe.DeleteUserMemoryReq{UserId: req.UserId, Key: req.Key})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.DeleteUserMemoryResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.DeleteUserMemoryResp{
			BaseResp: common.HandleRPCError(nil, "删除用户记忆成功"),
		})
	}
}

func getUserMemoriesDisplay(app *llmapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUserMemoriesReq
		if err := bindRequest(ctx, &req); err != nil {
			return err
		}
		userID, err := authUserIDFromBearer(ctx)
		if err != nil {
			return err
		}
		req.UserId = userID

		memResp, err := app.GetUserMemories(ctx, &moe.GetUserMemoriesReq{
			UserId: req.UserId, Limit: 200, Offset: 0,
		})
		if err != nil {
			base := common.HandleRPCError(err, "")
			return ctx.JSON(http.StatusOK, map[string]interface{}{
				"code": base.Code, "message": base.Message, "success": false,
			})
		}
		profResp, err := app.GetUserMemoryProfiles(ctx, &moe.GetUserMemoryProfilesReq{
			UserId: req.UserId, Limit: 12,
		})
		if err != nil {
			base := common.HandleRPCError(err, "")
			return ctx.JSON(http.StatusOK, map[string]interface{}{
				"code": base.Code, "message": base.Message, "success": false,
			})
		}
		data := userbiz.BuildUserMemoryDisplay(memResp.Memories, profResp.Profiles)
		base := common.HandleRPCError(nil, "获取记忆展示数据成功")
		return ctx.JSON(http.StatusOK, map[string]interface{}{
			"code": base.Code, "message": base.Message, "success": base.Success, "data": data,
		})
	}
}

func submitUserMemoryFeedback(app *llmapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.SubmitUserMemoryFeedbackReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.SubmitUserMemoryFeedbackResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.SubmitUserMemoryFeedback(ctx, &moe.SubmitUserMemoryFeedbackReq{
			UserId: req.UserId, Key: req.Key, FeedbackType: req.FeedbackType,
			CorrectedValue: req.CorrectedValue, Reason: req.Reason,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.SubmitUserMemoryFeedbackResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.SubmitUserMemoryFeedbackResp{
			BaseResp: common.HandleRPCError(nil, "提交记忆反馈成功"),
			Data:     userMemoryFromRPC(rpcResp.Memory),
		})
	}
}

func getUserMemoryProfiles(app *llmapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUserMemoryProfilesReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUserMemoryProfilesResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetUserMemoryProfiles(ctx, &moe.GetUserMemoryProfilesReq{
			UserId: req.UserId, Limit: int32(req.Limit),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUserMemoryProfilesResp{BaseResp: common.HandleRPCError(err, "")})
		}
		profiles := make([]types.UserMemoryProfile, 0, len(rpcResp.Profiles))
		for _, p := range rpcResp.Profiles {
			profiles = append(profiles, types.UserMemoryProfile{
				MemoryType: p.MemoryType, Summary: p.Summary,
				ItemCount: int(p.ItemCount), Confidence: p.Confidence,
			})
		}
		return ctx.JSON(http.StatusOK, types.GetUserMemoryProfilesResp{
			BaseResp: common.HandleRPCError(nil, "获取用户画像摘要成功"), Data: profiles,
		})
	}
}

func rebuildUserMemoryEmbeddings(app *llmapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		userID, err := authUserIDFromBearer(ctx)
		if err != nil {
			return err
		}
		resp, err := app.RebuildUserMemoryEmbeddings(ctx, &moe.RebuildUserMemoryEmbeddingsReq{UserId: userID})
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, map[string]interface{}{
			"indexed": resp.Indexed, "provider": resp.Provider, "model": resp.Model,
		})
	}
}

func searchUserMemories(svcCtx *svc.ServiceContext, app *llmapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.SearchUserMemoriesReq
		if err := bindRequest(ctx, &req); err != nil {
			return err
		}
		const listLimit = 200
		limit := req.Limit
		if limit <= 0 {
			limit = 8
		}
		memResp, err := app.GetUserMemories(ctx, &moe.GetUserMemoriesReq{
			UserId: req.UserId, Limit: listLimit, Offset: 0,
		})
		if err != nil {
			base := common.HandleRPCError(err, "")
			return ctx.JSON(http.StatusOK, map[string]interface{}{
				"code": base.Code, "message": base.Message, "success": false,
			})
		}
		result := userbiz.HybridSearchUserFacingMemories(ctx, userbiz.MemorySearchParams{
			Gateway:          svcCtx.LLMGW,
			InferenceBaseURL: svcCtx.Config.LLMInference.BaseUrl,
			UserID:           req.UserId,
			Memories:         memResp.Memories,
			Query:            req.Q,
			Limit:            limit,
		})
		base := common.HandleRPCError(nil, "记忆检索成功")
		return ctx.JSON(http.StatusOK, map[string]interface{}{
			"code": base.Code, "message": base.Message, "success": base.Success, "data": result,
		})
	}
}

func authUserIDFromBearer(ctx khttp.Context) (string, error) {
	authHeader := ctx.Request().Header.Get("Authorization")
	if len(authHeader) < 8 || authHeader[:7] != "Bearer " {
		return "", errors.New("missing or invalid authorization header")
	}
	tokenString := authHeader[7:]
	userID, err := utils.GetUserIDFromToken(tokenString)
	if err != nil {
		return "", err
	}
	return strconv.Itoa(int(userID)), nil
}
