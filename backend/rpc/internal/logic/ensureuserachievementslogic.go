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

type EnsureUserAchievementsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewEnsureUserAchievementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *EnsureUserAchievementsLogic {
	return &EnsureUserAchievementsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *EnsureUserAchievementsLogic) EnsureUserAchievements(in *moe.EnsureUserAchievementsReq) (*moe.EnsureUserAchievementsResp, error) {
	app := achievementapp.New(l.svcCtx.DB)
	resp, err := app.EnsureUserAchievements(l.ctx, in)
	if err != nil {
		if errors.Is(err, achievementbiz.ErrInvalidUserID) {
			return nil, fmt.Errorf("无效的用户ID: %v", err)
		}
		return nil, err
	}
	return resp, nil
}
