// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDashboardLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDashboardLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDashboardLogic {
	return &AdminDashboardLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminDashboardLogic) AdminDashboard(_ *types.EmptyReq) (resp *types.AdminDashboardResp, err error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminDashboard(l.ctx, &moe.AdminDashboardReq{})
	if err != nil {
		return &types.AdminDashboardResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.AdminDashboardResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminDashboardData{
			LandingFeedbackTotal: int(rpcResp.LandingFeedbackTotal),
			UserTotal:            int(rpcResp.UserTotal),
			ServerTime:           rpcResp.ServerTime,
			FeishuEnabled:        rpcResp.FeishuEnabled,
		},
	}, nil
}
