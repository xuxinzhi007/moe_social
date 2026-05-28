package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapAchievementsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminBootstrapAchievementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapAchievementsLogic {
	return &AdminBootstrapAchievementsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminBootstrapAchievementsLogic) AdminBootstrapAchievements(in *moe.AdminBootstrapAchievementsReq) (*moe.AdminBootstrapAchievementsResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).BootstrapAchievements(l.ctx, in)
	if err != nil {
		l.Errorf("[admin] bootstrap achievements: %v", err)
		return nil, errorx.Internal("初始化成就定义失败")
	}
	return resp, nil
}
