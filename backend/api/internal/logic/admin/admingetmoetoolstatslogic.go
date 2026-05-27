package admin

import (
	"context"

	moebiz "backend/internal/biz/moe"
	moeadmin "backend/internal/service/moe"
	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetMoeToolStatsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetMoeToolStatsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMoeToolStatsLogic {
	return &AdminGetMoeToolStatsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminGetMoeToolStatsLogic) AdminGetMoeToolStats(req *types.AdminGetMoeToolStatsReq) (*types.AdminGetMoeToolStatsResp, error) {
	stats, err := l.svcCtx.MoeGW.QueryToolStats(l.ctx, moebiz.ToolStatsFilter{
		From:     moeadmin.ParseTimeFilter(req.From, false),
		To:       moeadmin.ParseTimeFilter(req.To, true),
		AgentKey: req.AgentKey,
		Tool:     req.Tool,
	})
	if err != nil {
		return &types.AdminGetMoeToolStatsResp{BaseResp: common.HandleError(err)}, nil
	}
	return &types.AdminGetMoeToolStatsResp{
		BaseResp: common.HandleError(nil),
		Data:     moebridge.ToolStatsDataFromBiz(stats),
	}, nil
}
