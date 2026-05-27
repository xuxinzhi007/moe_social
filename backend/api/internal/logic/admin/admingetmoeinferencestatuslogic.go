package admin

import (
	"context"
	"strings"
	"time"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/model"
	"backend/pkg/moe/runtime"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetMoeInferenceStatusLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetMoeInferenceStatusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMoeInferenceStatusLogic {
	return &AdminGetMoeInferenceStatusLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminGetMoeInferenceStatusLogic) AdminGetMoeInferenceStatus(req *types.AdminGetMoeInferenceStatusReq) (*types.AdminGetMoeInferenceStatusResp, error) {
	cfg, err := common.InferenceFromLLMConf(l.svcCtx.Config.LLMInference)
	data := types.AdminGetMoeInferenceStatusData{
		BaseUrl:          cfg.BaseURL,
		DefaultPostModel: defaultPostModelFromViper(),
	}
	if err != nil || strings.TrimSpace(cfg.BaseURL) == "" {
		data.Message = "未配置 llm_inference.base_url"
		return &types.AdminGetMoeInferenceStatusResp{
			BaseResp: common.HandleError(nil),
			Data:     data,
		}, nil
	}

	ctx, cancel := context.WithTimeout(l.ctx, time.Duration(cfg.TimeoutSeconds)*time.Second)
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
	if agentKey != "" && l.svcCtx.SuperRpcClient != nil {
		if rt := findRuntimeByAgentKey(l.ctx, l.svcCtx.SuperRpcClient, agentKey); rt != nil {
			data.RuntimeModel = strings.TrimSpace(rt.ModelName)
			deps := runtime.Deps{Inference: runtime.LoadInferenceFromViper()}
			data.EffectiveModel = runtime.ResolvePostModel(deps, *rt)
		}
	}

	target := data.EffectiveModel
	if target == "" {
		target = data.DefaultPostModel
	}
	if data.Online && target != "" {
		for _, name := range data.Models {
			if name == target {
				data.ModelLoaded = true
				break
			}
		}
		if !data.ModelLoaded && data.Message == "" {
			data.Message = "推理服务在线，但未找到模型「" + target + "」"
		}
	}

	slot := common.FetchInferenceSlotInfo(ctx, client, cfg.BaseURL)
	data.ContextLimit = slot.ContextLimit
	data.ContextSource = slot.Source

	return &types.AdminGetMoeInferenceStatusResp{
		BaseResp: common.HandleError(nil),
		Data:     data,
	}, nil
}

func defaultPostModelFromViper() string {
	deps := runtime.Deps{Inference: runtime.LoadInferenceFromViper()}
	return runtime.ResolvePostModel(deps, model.MoeAgentRuntime{})
}

func findRuntimeByAgentKey(ctx context.Context, client super.SuperClient, agentKey string) *model.MoeAgentRuntime {
	resp, err := client.AdminListMoeRuntimes(ctx, &super.AdminListMoeRuntimesReq{})
	if err != nil || resp == nil {
		return nil
	}
	for _, item := range resp.Items {
		if item == nil || item.AgentKey != agentKey {
			continue
		}
		return &model.MoeAgentRuntime{
			AgentKey:  item.AgentKey,
			ModelName: item.ModelName,
		}
	}
	return nil
}
