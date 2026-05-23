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

type EnsureUserAchievementsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewEnsureUserAchievementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *EnsureUserAchievementsLogic {
	return &EnsureUserAchievementsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *EnsureUserAchievementsLogic) EnsureUserAchievements(in *super.EnsureUserAchievementsReq) (*super.EnsureUserAchievementsResp, error) {
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, fmt.Errorf("无效的用户ID: %v", err)
	}

	tx := l.svcCtx.DB.Begin()
	engine := achievement.NewEngine(l.svcCtx.DB)
	unlocks, err := engine.EnsureUserInitialized(tx, uint(userID))
	if err != nil {
		tx.Rollback()
		return nil, err
	}
	if err := tx.Commit().Error; err != nil {
		return nil, err
	}

	return &super.EnsureUserAchievementsResp{
		NewAchievements: achievement.UnlocksToProto(unlocks),
	}, nil
}
