package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/model"
	"backend/pkg/llminference"
	"backend/pkg/moe/runtime"
	"backend/utils"
	"context"
	"fmt"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
	"strings"
	"time"
)

func AdminGetMoeInferenceStatusHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.AdminGetMoeInferenceStatusReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		resp, err := func(req *types.AdminGetMoeInferenceStatusReq) (*types.AdminGetMoeInferenceStatusResp, error) {
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
			return &types.AdminGetMoeInferenceStatusResp{
			BaseResp: common.HandleError(nil),
			Data:     data,
			}, nil
			}

			ctx, cancel := context.WithTimeout(r.Context(), time.Duration(cfg.TimeoutSeconds)*time.Second)
			defer cancel()
			client := utils.NewHTTPClient(cfg.TimeoutSeconds)
			models, listErr := common.ListModelNames(ctx, client, cfg)
			if listErr != nil {
			data.Message = listErr.Error()
			} else {
			data.Online = true
			data.Models = models
			}

			agentKey := strings.TrimSpace(req.AgentKey)
			if agentKey != "" && svcCtx.MoeGW != nil {
			if rt := svcCtx.MoeGW.FindRuntimeByAgentKey(r.Context(), agentKey); rt != nil {
			data.RuntimeModel = strings.TrimSpace(rt.ModelName)
			preferred = runtime.ConfiguredPostModel(deps, *rt)
			data.PreferredModel = preferred
			data.DefaultPostModel = preferred
			}
			}

			pick := llminference.PickModel(preferred, data.Models)
			data.EffectiveModel = pick.ModelID
			data.AutoDiscovered = pick.AutoDiscovered
			data.ModelLoaded = data.Online && pick.ModelID != "" && modelInList(pick.ModelID, data.Models)

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

			slot := common.FetchInferenceSlotInfo(ctx, client, cfg.BaseURL)
			data.ContextLimit = slot.ContextLimit
			data.ContextSource = slot.Source

			return &types.AdminGetMoeInferenceStatusResp{
			BaseResp: common.HandleError(nil),
			Data:     data,
			}, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
