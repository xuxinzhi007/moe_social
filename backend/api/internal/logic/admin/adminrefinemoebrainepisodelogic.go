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

type AdminRefineMoeBrainEpisodeLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminRefineMoeBrainEpisodeLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminRefineMoeBrainEpisodeLogic {
	return &AdminRefineMoeBrainEpisodeLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminRefineMoeBrainEpisodeLogic) AdminRefineMoeBrainEpisode(req *types.AdminRefineMoeBrainEpisodeReq) (*types.AdminRefineMoeBrainEpisodeResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminRefineMoeBrainEpisode(l.ctx, &super.AdminRefineMoeBrainEpisodeReq{
		Id:          uint64(req.Id),
		MaxAttempts: int32(req.MaxAttempts),
	})
	if err != nil {
		return &types.AdminRefineMoeBrainEpisodeResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminRefineMoeBrainEpisodeResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     moebridge.RefineResultFromRPC(rpcResp),
	}, nil
}
