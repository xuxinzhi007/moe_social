package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetMoeBrainPipelineLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetMoeBrainPipelineLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMoeBrainPipelineLogic {
	return &AdminGetMoeBrainPipelineLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminGetMoeBrainPipelineLogic) AdminGetMoeBrainPipeline(req *types.AdminGetMoeBrainPipelineReq) (*types.AdminGetMoeBrainPipelineResp, error) {
	snap, err := l.svcCtx.MoeGW.GetBrainPipeline(l.ctx, req.AgentKey)
	if err != nil {
		return &types.AdminGetMoeBrainPipelineResp{BaseResp: common.HandleError(err)}, nil
	}
	return &types.AdminGetMoeBrainPipelineResp{
		BaseResp: common.HandleError(nil),
		Data:     moebridge.PipelineDataFromBiz(snap),
	}, nil
}
