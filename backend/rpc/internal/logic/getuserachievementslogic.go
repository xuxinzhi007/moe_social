package logic

import (
	"context"
	"errors"
	"fmt"

	achievementapp "backend/internal/service/achievement"
	achievementbiz "backend/internal/biz/achievement"
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
	return &GetUserAchievementsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetUserAchievementsLogic) GetUserAchievements(in *super.GetUserAchievementsReq) (*super.GetUserAchievementsResp, error) {
	app := achievementapp.New(l.svcCtx.DB)
	resp, err := app.GetUserAchievements(l.ctx, in)
	if err != nil {
		if errors.Is(err, achievementbiz.ErrInvalidUserID) {
			return nil, fmt.Errorf("无效的用户ID: %v", err)
		}
		return nil, err
	}
	return resp, nil
}
