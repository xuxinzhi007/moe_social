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

type GetUserAchievementsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserAchievementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserAchievementsLogic {
	return &GetUserAchievementsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserAchievementsLogic) GetUserAchievements(in *super.GetUserAchievementsReq) (*super.GetUserAchievementsResp, error) {
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, fmt.Errorf("无效的用户ID: %v", err)
	}

	engine := achievement.NewEngine(l.svcCtx.DB)
	badges, err := engine.ListUserAchievements(l.svcCtx.DB, uint(userID), true)
	if err != nil {
		return nil, err
	}

	return &super.GetUserAchievementsResp{
		Badges: achievement.BadgesToProto(badges),
	}, nil
}
