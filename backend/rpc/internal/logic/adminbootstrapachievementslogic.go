package logic

import (
	"context"

	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapAchievementsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminBootstrapAchievementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapAchievementsLogic {
	return &AdminBootstrapAchievementsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminBootstrapAchievementsLogic) AdminBootstrapAchievements(in *super.AdminBootstrapAchievementsReq) (*super.AdminBootstrapAchievementsResp, error) {
	_ = in
	created, err := utils.BootstrapAchievementDefinitions(l.svcCtx.DB)
	if err != nil {
		l.Errorf("[admin] bootstrap achievements: %v", err)
		return nil, errorx.Internal("初始化成就定义失败")
	}
	return &super.AdminBootstrapAchievementsResp{Created: created}, nil
}
