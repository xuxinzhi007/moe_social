package admin

import (
	"context"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetMoeBrainLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetMoeBrainLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMoeBrainLogic {
	return &AdminGetMoeBrainLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminGetMoeBrainLogic) AdminGetMoeBrain(req *types.AdminGetMoeBrainReq) (*types.AdminGetMoeBrainResp, error) {
	agentKey := strings.TrimSpace(req.AgentKey)
	snap, err := l.svcCtx.MoeGW.GetBrainSnapshot(l.ctx, agentKey)
	if err != nil {
		return &types.AdminGetMoeBrainResp{BaseResp: common.HandleError(err)}, nil
	}
	return &types.AdminGetMoeBrainResp{
		BaseResp: common.HandleError(nil),
		Data:     moebridge.BrainDataFromSnapshot(snap),
	}, nil
}
