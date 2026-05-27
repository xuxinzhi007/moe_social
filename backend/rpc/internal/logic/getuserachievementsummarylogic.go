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

type GetUserAchievementSummaryLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserAchievementSummaryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserAchievementSummaryLogic {
	return &GetUserAchievementSummaryLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetUserAchievementSummaryLogic) GetUserAchievementSummary(in *super.GetUserAchievementSummaryReq) (*super.GetUserAchievementSummaryResp, error) {
	app := achievementapp.New(l.svcCtx.DB)
	resp, err := app.GetUserAchievementSummary(l.ctx, in)
	if err != nil {
		if errors.Is(err, achievementbiz.ErrInvalidUserID) {
			return nil, fmt.Errorf("无效的用户ID: %v", err)
		}
		return nil, err
	}
	return resp, nil
}
