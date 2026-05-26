package admin

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

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
	_, err := l.svcCtx.SuperRpcClient.AdminDeleteMoeBrainEpisode(l.ctx, &super.AdminDeleteMoeBrainEpisodeReq{
		Id: uint64(req.Id),
	})
	if err != nil {
		return &types.BaseResp{Code: 404, Message: err.Error(), Success: false}, nil
	}
	return &types.BaseResp{Code: 0, Message: "ok", Success: true}, nil
}
