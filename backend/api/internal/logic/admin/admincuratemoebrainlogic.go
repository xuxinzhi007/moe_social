package admin

import (
	"context"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/pkg/moe/brain"

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
	agentKey := strings.TrimSpace(req.AgentKey)
	results, err := l.svcCtx.MoeGW.CurateBrain(l.ctx, agentKey, brain.CurateOptions{
		MaxEpisodes:           req.MaxEpisodes,
		MaxAttemptsPerEpisode: req.MaxAttempts,
		MinQuality:            req.MinQuality,
		Force:                 req.Force,
	})
	if err != nil {
		return &types.AdminCurateMoeBrainResp{BaseResp: common.HandleError(err)}, nil
	}
	out := types.AdminCurateMoeBrainData{AgentKey: agentKey, Total: len(results)}
	for _, r := range results {
		if r.Approved {
			out.Approved++
		}
		out.Results = append(out.Results, moebridge.RefineDataFromBiz(r))
	}
	return &types.AdminCurateMoeBrainResp{
		BaseResp: common.HandleError(nil),
		Data:     out,
	}, nil
}
