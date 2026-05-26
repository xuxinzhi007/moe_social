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

type AdminCurateMoeBrainLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminCurateMoeBrainLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCurateMoeBrainLogic {
	return &AdminCurateMoeBrainLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminCurateMoeBrainLogic) AdminCurateMoeBrain(req *types.AdminCurateMoeBrainReq) (*types.AdminCurateMoeBrainResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.AdminCurateMoeBrain(l.ctx, &super.AdminCurateMoeBrainReq{
		AgentKey:    req.AgentKey,
		MaxEpisodes: int32(req.MaxEpisodes),
		MaxAttempts: int32(req.MaxAttempts),
		MinQuality:  int32(req.MinQuality),
		Force:       req.Force,
	})
	if err != nil {
		return &types.AdminCurateMoeBrainResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	results := make([]types.AdminRefineMoeBrainEpisodeData, 0, len(rpcResp.Results))
	for _, r := range rpcResp.Results {
		results = append(results, moebridge.RefineResultFromRPC(r))
	}
	return &types.AdminCurateMoeBrainResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminCurateMoeBrainData{
			AgentKey: rpcResp.AgentKey,
			Total:    int(rpcResp.Total),
			Approved: int(rpcResp.Approved),
			Results:  results,
		},
	}, nil
}
