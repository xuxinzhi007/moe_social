package moehttp

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"

	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	moebiz "backend/internal/biz/moe"
	moeadmin "backend/internal/service/moe"
	"backend/model"
	"backend/pkg/llminference"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/core"
	"backend/pkg/moe/runtime"
	"backend/pkg/moe/toolaudit"
	"backend/pkg/moe/tools"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func moeAdminUnavailable() types.BaseResp {
	return types.BaseResp{Code: -1, Message: "MoeAdmin 未配置", Success: false}
}

func adminDeleteMoeBrainEpisode(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if admin == nil {
			return ctx.JSON(http.StatusOK, moeAdminUnavailable())
		}
		var req types.AdminDeleteMoeBrainEpisodeReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		if err := admin.DeleteBrainEpisode(ctx, req.Id); err != nil {
			return ctx.JSON(http.StatusOK, common.HandleError(err))
		}
		return ctx.JSON(http.StatusOK, common.HandleError(nil))
	}
}

func adminRefineMoeBrainEpisode(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if admin == nil {
			return ctx.JSON(http.StatusOK, types.AdminRefineMoeBrainEpisodeResp{BaseResp: moeAdminUnavailable()})
		}
		var req types.AdminRefineMoeBrainEpisodeReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		res, err := admin.RefineBrainEpisode(ctx, req.Id, brain.RefineOptions{MaxAttempts: req.MaxAttempts})
		if err != nil && !res.OK {
			return ctx.JSON(http.StatusOK, types.AdminRefineMoeBrainEpisodeResp{BaseResp: common.HandleError(err)})
		}
		return ctx.JSON(http.StatusOK, types.AdminRefineMoeBrainEpisodeResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.RefineDataFromBiz(res),
		})
	}
}

// adminStreamMoeBrainPipeline SSE：试跑流水线实时推送（tier-A，直写 ResponseWriter）。
func adminStreamMoeBrainPipeline(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		w := ctx.Response()
		r := ctx.Request()
		var req types.AdminGetMoeBrainPipelineReq
		if err := bindRequest(ctx, &req); err != nil {
			return err
		}
		agentKey := req.AgentKey
		if agentKey == "" {
			_ = common.WriteSSE(w, "error", types.AdminGetMoeBrainPipelineResp{
				BaseResp: common.HandleError(fmt.Errorf("agent_key is required")),
			})
			return nil
		}
		if admin == nil {
			_ = common.WriteSSE(w, "error", types.AdminGetMoeBrainPipelineResp{
				BaseResp: moeAdminUnavailable(),
			})
			return nil
		}

		common.InitSSEHeaders(w)
		w.WriteHeader(http.StatusOK)

		send := func() bool {
			snap, err := admin.GetBrainPipeline(r.Context(), agentKey)
			if err != nil {
				_ = common.WriteSSE(w, "error", types.AdminGetMoeBrainPipelineResp{
					BaseResp: common.HandleError(err),
				})
				return false
			}
			if err := common.WriteSSE(w, "pipeline", types.AdminGetMoeBrainPipelineResp{
				BaseResp: common.HandleError(nil),
				Data:     moebridge.PipelineDataFromBiz(snap),
			}); err != nil {
				return false
			}
			return !snap.Running
		}

		if send() {
			_ = common.WriteSSE(w, "done", map[string]bool{"ok": true})
			return nil
		}

		updates, unsub := runtime.LiveRuns.Subscribe(agentKey)
		defer unsub()

		heartbeat := time.NewTicker(25 * time.Second)
		defer heartbeat.Stop()

		for {
			select {
			case <-r.Context().Done():
				return nil
			case <-heartbeat.C:
				if err := common.WriteSSE(w, "ping", map[string]string{"t": "ok"}); err != nil {
					return nil
				}
			case _, open := <-updates:
				if !open {
					return nil
				}
				if send() {
					_ = common.WriteSSE(w, "done", map[string]bool{"ok": true})
					return nil
				}
			}
		}
	}
}

func adminGetMoeInferenceStatus(admin *moeadmin.AdminService, svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AdminGetMoeInferenceStatusReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		cfg, err := common.InferenceFromLLMConf(svcCtx.Config.LLMInference)
		deps := runtime.Deps{Inference: runtime.LoadInferenceFromViper()}
		preferred := runtime.ConfiguredPostModel(deps, model.MoeAgentRuntime{})

		data := types.AdminGetMoeInferenceStatusData{
			BaseUrl:          cfg.BaseURL,
			DefaultPostModel: preferred,
			PreferredModel:   preferred,
		}
		if err != nil || strings.TrimSpace(cfg.BaseURL) == "" {
			data.Message = "未配置 llm_inference.base_url"
			return ctx.JSON(http.StatusOK, types.AdminGetMoeInferenceStatusResp{
				BaseResp: common.HandleError(nil),
				Data:     data,
			})
		}

		inferCtx, cancel := context.WithTimeout(ctx, time.Duration(cfg.TimeoutSeconds)*time.Second)
		defer cancel()
		client := utils.NewHTTPClient(cfg.TimeoutSeconds)
		models, listErr := common.ListModelNames(inferCtx, client, cfg)
		if listErr != nil {
			data.Message = listErr.Error()
		} else {
			data.Online = true
			data.Models = models
		}

		agentKey := strings.TrimSpace(req.AgentKey)
		if agentKey != "" && admin != nil {
			rt, rtErr := admin.FindRuntimeByAgentKey(ctx, agentKey)
			if rtErr != nil {
				return ctx.JSON(http.StatusOK, types.AdminGetMoeInferenceStatusResp{
					BaseResp: common.HandleError(rtErr),
				})
			}
			if rt != nil {
				data.RuntimeModel = strings.TrimSpace(rt.ModelName)
				preferred = runtime.ConfiguredPostModel(deps, *rt)
				data.PreferredModel = preferred
				data.DefaultPostModel = preferred
			}
		}

		pick := llminference.PickModel(preferred, data.Models)
		data.EffectiveModel = pick.ModelID
		data.AutoDiscovered = pick.AutoDiscovered
		data.ModelLoaded = data.Online && pick.ModelID != "" && inferenceModelInList(pick.ModelID, data.Models)

		if data.Online && !data.ModelLoaded && data.Message == "" {
			if len(data.Models) == 0 {
				data.Message = "推理服务在线，但未返回可用模型列表"
			} else {
				data.Message = fmt.Sprintf("推理服务在线，但未找到模型「%s」", preferred)
			}
		}
		if data.AutoDiscovered && data.ModelLoaded && pick.Preferred != "" && !strings.EqualFold(pick.Preferred, pick.ModelID) {
			data.Message = fmt.Sprintf("已自动选用「%s」（配置偏好「%s」）", pick.ModelID, pick.Preferred)
		}

		slot := common.FetchInferenceSlotInfo(inferCtx, client, cfg.BaseURL)
		data.ContextLimit = slot.ContextLimit
		data.ContextSource = slot.Source

		return ctx.JSON(http.StatusOK, types.AdminGetMoeInferenceStatusResp{
			BaseResp: common.HandleError(nil),
			Data:     data,
		})
	}
}

func inferenceModelInList(id string, models []string) bool {
	for _, m := range models {
		if strings.EqualFold(strings.TrimSpace(m), strings.TrimSpace(id)) {
			return true
		}
	}
	return false
}

func adminGetMoeBrain(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if admin == nil {
			return ctx.JSON(http.StatusOK, types.AdminGetMoeBrainResp{BaseResp: moeAdminUnavailable()})
		}
		var req types.AdminGetMoeBrainReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		agentKey := strings.TrimSpace(req.AgentKey)
		snap, err := admin.GetBrainSnapshot(ctx, agentKey)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminGetMoeBrainResp{BaseResp: common.HandleError(err)})
		}
		return ctx.JSON(http.StatusOK, types.AdminGetMoeBrainResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.BrainDataFromSnapshot(snap),
		})
	}
}

func adminCurateMoeBrain(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if admin == nil {
			return ctx.JSON(http.StatusOK, types.AdminCurateMoeBrainResp{BaseResp: moeAdminUnavailable()})
		}
		var req types.AdminCurateMoeBrainReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		agentKey := strings.TrimSpace(req.AgentKey)
		results, err := admin.CurateBrain(ctx, agentKey, brain.CurateOptions{
			MaxEpisodes:           req.MaxEpisodes,
			MaxAttemptsPerEpisode: req.MaxAttempts,
			MinQuality:            req.MinQuality,
			Force:                 req.Force,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminCurateMoeBrainResp{BaseResp: common.HandleError(err)})
		}
		out := types.AdminCurateMoeBrainData{AgentKey: agentKey, Total: len(results)}
		for _, r := range results {
			if r.Approved {
				out.Approved++
			}
			out.Results = append(out.Results, moebridge.RefineDataFromBiz(r))
		}
		return ctx.JSON(http.StatusOK, types.AdminCurateMoeBrainResp{
			BaseResp: common.HandleError(nil),
			Data:     out,
		})
	}
}

func adminUpdateMoeBrainPolicy(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if admin == nil {
			return ctx.JSON(http.StatusOK, types.AdminGetMoeBrainResp{BaseResp: moeAdminUnavailable()})
		}
		var req types.AdminUpdateMoeBrainPolicyReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		agentKey := strings.TrimSpace(req.AgentKey)
		snap, err := admin.UpdateBrainPolicy(ctx, agentKey, req.ForbiddenTags, req.PreferredTags)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminGetMoeBrainResp{BaseResp: common.HandleError(err)})
		}
		return ctx.JSON(http.StatusOK, types.AdminGetMoeBrainResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.BrainDataFromSnapshot(snap),
		})
	}
}

func adminGetMoeBotFlow(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if admin == nil {
			return ctx.JSON(http.StatusOK, types.AdminGetMoeBotFlowResp{BaseResp: moeAdminUnavailable()})
		}
		var req types.AdminGetMoeBotFlowReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		agentKey := strings.TrimSpace(req.AgentKey)
		cfg, err := admin.GetBotFlowConfig(ctx, agentKey)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminGetMoeBotFlowResp{BaseResp: common.HandleError(err)})
		}
		cfg.AgentKey = agentKey
		return ctx.JSON(http.StatusOK, types.AdminGetMoeBotFlowResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.FlowDataFromBiz(cfg),
		})
	}
}

func adminUpsertMoeBotFlow(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if admin == nil {
			return ctx.JSON(http.StatusOK, types.AdminUpsertMoeBotFlowResp{BaseResp: moeAdminUnavailable()})
		}
		var req types.AdminUpsertMoeBotFlowReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		agentKey := strings.TrimSpace(req.AgentKey)
		in := moebridge.FlowConfigFromTypes(&req)
		saved, err := admin.UpsertBotFlowConfig(ctx, agentKey, in)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpsertMoeBotFlowResp{BaseResp: common.HandleError(err)})
		}
		saved.AgentKey = agentKey
		return ctx.JSON(http.StatusOK, types.AdminUpsertMoeBotFlowResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.FlowDataFromBiz(saved),
		})
	}
}

func adminDeleteMoeBotFlow(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if admin == nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteMoeBotFlowResp{BaseResp: moeAdminUnavailable()})
		}
		var req types.AdminDeleteMoeBotFlowReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		agentKey := strings.TrimSpace(req.AgentKey)
		cfg, err := admin.DeleteBotFlowConfig(ctx, agentKey)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminDeleteMoeBotFlowResp{BaseResp: common.HandleError(err)})
		}
		cfg.AgentKey = agentKey
		return ctx.JSON(http.StatusOK, types.AdminDeleteMoeBotFlowResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.FlowDataFromBiz(cfg),
		})
	}
}

func adminRunMoeAgentOnce(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if admin == nil {
			return ctx.JSON(http.StatusOK, types.AdminRunMoeAgentResp{BaseResp: moeAdminUnavailable()})
		}
		var req types.AdminRunMoeAgentReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		agentKey := strings.TrimSpace(req.AgentKey)
		out, err := admin.RunAgentOnce(ctx, agentKey, req.Async)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminRunMoeAgentResp{BaseResp: common.HandleError(err)})
		}
		data := types.AdminRunMoeAgentData{
			AgentKey:       agentKey,
			Accepted:       out.Accepted,
			AlreadyRunning: out.AlreadyRunning,
		}
		if !out.Accepted && !out.AlreadyRunning {
			data.Ok = out.Result.OK
			data.Detail = out.Result.Detail
			data.PostId = out.Result.PostID
			if data.AgentKey == "" {
				data.AgentKey = out.Result.AgentKey
			}
		}
		return ctx.JSON(http.StatusOK, types.AdminRunMoeAgentResp{
			BaseResp: common.HandleError(nil),
			Data:     data,
		})
	}
}

func adminListMoeToolCalls(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if admin == nil {
			return ctx.JSON(http.StatusOK, types.AdminListMoeToolCallsResp{BaseResp: moeAdminUnavailable()})
		}
		var req types.AdminListMoeToolCallsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rows, total, err := admin.ListToolCalls(ctx, moebiz.ToolCallsFilter{
			From:        moeadmin.ParseTimeFilter(req.From, false),
			To:          moeadmin.ParseTimeFilter(req.To, true),
			AgentKey:    req.AgentKey,
			Tool:        req.Tool,
			Source:      req.Source,
			ActorUserID: moebiz.ParseActorUserID(req.ActorUserId),
			OkOnly:      req.OkOnly,
			FailedOnly:  req.FailedOnly,
			Page:        req.Page,
			PageSize:    req.PageSize,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListMoeToolCallsResp{BaseResp: common.HandleError(err)})
		}
		return ctx.JSON(http.StatusOK, types.AdminListMoeToolCallsResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.ToolCallsDataFromBiz(rows, total),
		})
	}
}

func adminGetMoeToolsSchema() func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		items := toolaudit.BuildSchemaItems()
		toolsOut := make([]types.AdminMoeToolSchemaItem, 0, len(items))
		for _, it := range items {
			toolsOut = append(toolsOut, types.AdminMoeToolSchemaItem{
				Name:         it.Name,
				Description:  it.Description,
				AllowedTiers: it.AllowedTiers,
			})
		}
		openai := tools.OpenAISchemaList()
		openaiOut := make([]interface{}, 0, len(openai))
		for _, o := range openai {
			openaiOut = append(openaiOut, o)
		}
		return ctx.JSON(http.StatusOK, types.AdminGetMoeToolsSchemaResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data: types.AdminMoeToolsSchemaData{
				DefaultTier: string(core.DefaultTier),
				Tools:       toolsOut,
				OpenAITools: openaiOut,
			},
		})
	}
}

func adminGetMoeToolStats(admin *moeadmin.AdminService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if admin == nil {
			return ctx.JSON(http.StatusOK, types.AdminGetMoeToolStatsResp{BaseResp: moeAdminUnavailable()})
		}
		var req types.AdminGetMoeToolStatsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		stats, err := admin.QueryToolStats(ctx, moebiz.ToolStatsFilter{
			From:     moeadmin.ParseTimeFilter(req.From, false),
			To:       moeadmin.ParseTimeFilter(req.To, true),
			AgentKey: req.AgentKey,
			Tool:     req.Tool,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminGetMoeToolStatsResp{BaseResp: common.HandleError(err)})
		}
		return ctx.JSON(http.StatusOK, types.AdminGetMoeToolStatsResp{
			BaseResp: common.HandleError(nil),
			Data:     moebridge.ToolStatsDataFromBiz(stats),
		})
	}
}
