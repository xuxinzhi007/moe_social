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

type AdminUpdateMoeBrainPolicyLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpdateMoeBrainPolicyLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateMoeBrainPolicyLogic {
	return &AdminUpdateMoeBrainPolicyLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminUpdateMoeBrainPolicyLogic) AdminUpdateMoeBrainPolicy(req *types.AdminUpdateMoeBrainPolicyReq) (*types.AdminGetMoeBrainResp, error) {
	agentKey := strings.TrimSpace(req.AgentKey)
	snap, err := l.svcCtx.MoeGW.UpdateBrainPolicy(l.ctx, agentKey, req.ForbiddenTags, req.PreferredTags)
	if err != nil {
		return &types.AdminGetMoeBrainResp{BaseResp: common.HandleError(err)}, nil
	}
	return &types.AdminGetMoeBrainResp{
		BaseResp: common.HandleError(nil),
		Data:     moebridge.BrainDataFromSnapshot(snap),
	}, nil
}
