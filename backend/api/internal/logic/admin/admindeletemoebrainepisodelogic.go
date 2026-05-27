package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteMoeBrainEpisodeLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeleteMoeBrainEpisodeLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteMoeBrainEpisodeLogic {
	return &AdminDeleteMoeBrainEpisodeLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminDeleteMoeBrainEpisodeLogic) AdminDeleteMoeBrainEpisode(req *types.AdminDeleteMoeBrainEpisodeReq) (*types.BaseResp, error) {
	if err := l.svcCtx.MoeGW.DeleteBrainEpisode(l.ctx, req.Id); err != nil {
		br := common.HandleError(err)
		return &br, nil
	}
	br := common.HandleError(nil)
	return &br, nil
}
