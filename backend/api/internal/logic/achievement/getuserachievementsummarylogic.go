package achievement

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserAchievementSummaryLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetUserAchievementSummaryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserAchievementSummaryLogic {
	return &GetUserAchievementSummaryLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetUserAchievementSummaryLogic) GetUserAchievementSummary(req *types.GetUserAchievementSummaryReq) (*types.GetUserAchievementSummaryResp, error) {
	rpcResp, err := l.svcCtx.AchievementGW.GetUserAchievementSummary(l.ctx, &super.GetUserAchievementSummaryReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.GetUserAchievementSummaryResp{
			BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
		}, nil
	}

	s := rpcResp.Summary
	return &types.GetUserAchievementSummaryResp{
		BaseResp: types.BaseResp{Code: 0, Message: "获取成就概览成功", Success: true},
		Data: types.AchievementSummary{
			TotalBadges:          int(s.TotalBadges),
			UnlockedBadges:       int(s.UnlockedBadges),
			CompletionPercentage: s.CompletionPercentage,
		},
	}, nil
}
