package logic

import (
	"context"
	"errors"
	"fmt"

	achievementapp "backend/internal/service/achievement"
	achievementbiz "backend/internal/biz/achievement"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserUnlockedAchievementsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserUnlockedAchievementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserUnlockedAchievementsLogic {
	return &GetUserUnlockedAchievementsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetUserUnlockedAchievementsLogic) GetUserUnlockedAchievements(in *moe.GetUserUnlockedAchievementsReq) (*moe.GetUserUnlockedAchievementsResp, error) {
	app := achievementapp.New(l.svcCtx.DB)
	resp, err := app.GetUserUnlockedAchievements(l.ctx, in)
	if err != nil {
		if errors.Is(err, achievementbiz.ErrInvalidUserID) {
			return nil, fmt.Errorf("无效的用户ID: %v", err)
		}
		return nil, err
	}
	return resp, nil
}
