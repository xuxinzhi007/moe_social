package ai

import (
	"context"
	"strconv"

	"backend/api/internal/common"
	llmlogic "backend/api/internal/logic/llm"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetAiMemorySettingsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetAiMemorySettingsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetAiMemorySettingsLogic {
	return &GetAiMemorySettingsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *GetAiMemorySettingsLogic) GetAiMemorySettings(_ *types.EmptyReq) (*types.AiMemorySettingsResp, error) {
	userID, err := common.UserIDUint(l.ctx)
	if err != nil {
		return nil, err
	}
	uid := strconv.FormatUint(uint64(userID), 10)
	auto := llmlogic.UserMemoryAutoLearnEnabled(l.ctx, l.svcCtx, uid)
	return &types.AiMemorySettingsResp{
		BaseResp: common.HandleError(nil),
		Data:     types.AiMemorySettingsData{AutoLearn: auto},
	}, nil
}
