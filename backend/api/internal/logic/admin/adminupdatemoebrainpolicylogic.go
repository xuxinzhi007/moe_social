package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

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
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminUpdateMoeBrainPolicy(l.ctx, &super.AdminUpdateMoeBrainPolicyReq{
		AgentKey:      req.AgentKey,
		ForbiddenTags: req.ForbiddenTags,
		PreferredTags: req.PreferredTags,
	})
	if err != nil {
		return &types.AdminGetMoeBrainResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminGetMoeBrainResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     moebridge.BrainDataFromRPC(rpcResp),
	}, nil
}
