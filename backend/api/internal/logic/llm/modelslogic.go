package llm

import (
	"context"
	"time"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type ModelsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewModelsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ModelsLogic {
	return &ModelsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ModelsLogic) Models(req *types.EmptyReq) (resp *types.LlmModelsResp, err error) {
	if models, found := l.svcCtx.ModelCache.Get(); found {
		return &types.LlmModelsResp{
			BaseResp: common.HandleError(nil),
			Models:   models,
		}, nil
	}

	var names []string
	if l.svcCtx.LLMApp != nil {
		names, err = l.svcCtx.LLMApp.ListModels(l.ctx)
	} else {
		cfg, cfgErr := common.InferenceFromLLMConf(l.svcCtx.Config.LLMInference)
		if cfgErr != nil {
			return &types.LlmModelsResp{
				BaseResp: common.HandleError(cfgErr),
				Models:   nil,
			}, nil
		}
		ctx, cancel := context.WithTimeout(l.ctx, time.Duration(cfg.TimeoutSeconds)*time.Second)
		defer cancel()
		client := utils.NewHTTPClient(cfg.TimeoutSeconds)
		names, err = common.ListModelNames(ctx, client, cfg)
	}
	if err != nil {
		return &types.LlmModelsResp{
			BaseResp: common.HandleError(err),
			Models:   nil,
		}, nil
	}

	l.svcCtx.ModelCache.Set(names)

	return &types.LlmModelsResp{
		BaseResp: common.HandleError(nil),
		Models:   names,
	}, nil
}
