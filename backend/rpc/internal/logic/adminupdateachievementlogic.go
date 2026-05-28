package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateAchievementLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateAchievementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateAchievementLogic {
	return &AdminUpdateAchievementLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpdateAchievementLogic) AdminUpdateAchievement(in *moe.AdminUpdateAchievementReq) (*moe.AdminUpdateAchievementResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).UpdateAchievement(l.ctx, in)
	if err != nil {
		return nil, mapAdminAchievementWriteErr(err)
	}
	return resp, nil
}
