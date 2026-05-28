package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListAchievementsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListAchievementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAchievementsLogic {
	return &AdminListAchievementsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListAchievementsLogic) AdminListAchievements(in *moe.AdminListAchievementsReq) (*moe.AdminListAchievementsResp, error) {
	return adminapp.New(l.svcCtx.DB).ListAchievements(l.ctx, in)
}
