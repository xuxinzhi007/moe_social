package logic

import (
	"context"
	"fmt"
	"strconv"

	"backend/rpc/internal/achievement"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserAchievementSummaryLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserAchievementSummaryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserAchievementSummaryLogic {
	return &GetUserAchievementSummaryLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserAchievementSummaryLogic) GetUserAchievementSummary(in *super.GetUserAchievementSummaryReq) (*super.GetUserAchievementSummaryResp, error) {
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, fmt.Errorf("无效的用户ID: %v", err)
	}

	engine := achievement.NewEngine(l.svcCtx.DB)
	summary, err := engine.GetSummary(l.svcCtx.DB, uint(userID))
	if err != nil {
		return nil, err
	}

	return &super.GetUserAchievementSummaryResp{
		Summary: &super.AchievementSummary{
			TotalBadges:          int32(summary.TotalBadges),
			UnlockedBadges:       int32(summary.UnlockedBadges),
			CompletionPercentage: summary.CompletionPercentage,
		},
	}, nil
}
