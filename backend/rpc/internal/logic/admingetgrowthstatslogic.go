package logic

import (
	"context"

	adminbiz "backend/internal/biz/admin"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetGrowthStatsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetGrowthStatsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetGrowthStatsLogic {
	return &AdminGetGrowthStatsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminGetGrowthStatsLogic) AdminGetGrowthStats(_ *moe.AdminGetGrowthStatsReq) (*moe.AdminGetGrowthStatsResp, error) {
	stats, err := adminbiz.GrowthStats(l.ctx, l.svcCtx.DB)
	if err != nil {
		l.Errorf("[admin] growth stats: %v", err)
		return nil, errorx.Internal("查询成长统计失败")
	}
	return &moe.AdminGetGrowthStatsResp{Stats: stats}, nil
}
