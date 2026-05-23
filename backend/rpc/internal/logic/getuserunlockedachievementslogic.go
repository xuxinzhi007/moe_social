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

type GetUserUnlockedAchievementsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserUnlockedAchievementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserUnlockedAchievementsLogic {
	return &GetUserUnlockedAchievementsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserUnlockedAchievementsLogic) GetUserUnlockedAchievements(in *super.GetUserUnlockedAchievementsReq) (*super.GetUserUnlockedAchievementsResp, error) {
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, fmt.Errorf("无效的用户ID: %v", err)
	}

	engine := achievement.NewEngine(l.svcCtx.DB)
	all, err := engine.ListUserAchievements(l.svcCtx.DB, uint(userID), true)
	if err != nil {
		return nil, err
	}
	unlocked := make([]achievement.BadgeDTO, 0)
	for _, b := range all {
		if b.IsUnlocked {
			unlocked = append(unlocked, b)
		}
	}

	return &super.GetUserUnlockedAchievementsResp{
		Badges: achievement.BadgesToProto(unlocked),
	}, nil
}
