package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/pkg/moe/brain"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminRefineMoeBrainEpisodeLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminRefineMoeBrainEpisodeLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminRefineMoeBrainEpisodeLogic {
	return &AdminRefineMoeBrainEpisodeLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminRefineMoeBrainEpisodeLogic) AdminRefineMoeBrainEpisode(req *types.AdminRefineMoeBrainEpisodeReq) (*types.AdminRefineMoeBrainEpisodeResp, error) {
	res, err := l.svcCtx.MoeGW.RefineBrainEpisode(l.ctx, req.Id, brain.RefineOptions{MaxAttempts: req.MaxAttempts})
	if err != nil && !res.OK {
		return &types.AdminRefineMoeBrainEpisodeResp{BaseResp: common.HandleError(err)}, nil
	}
	return &types.AdminRefineMoeBrainEpisodeResp{
		BaseResp: common.HandleError(nil),
		Data:     moebridge.RefineDataFromBiz(res),
	}, nil
}
