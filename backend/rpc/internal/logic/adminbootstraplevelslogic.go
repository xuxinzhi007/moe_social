package logic

import (
	"context"

	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapLevelsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminBootstrapLevelsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapLevelsLogic {
	return &AdminBootstrapLevelsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminBootstrapLevelsLogic) AdminBootstrapLevels(_ *super.AdminBootstrapLevelsReq) (*super.AdminBootstrapLevelsResp, error) {
	levelCreated, rewardCreated, err := utils.BootstrapLevelData(l.svcCtx.DB)
	if err != nil {
		l.Errorf("[admin] bootstrap levels: %v", err)
		return nil, errorx.Internal("初始化等级数据失败")
	}
	return &super.AdminBootstrapLevelsResp{
		LevelConfigsCreated:   levelCreated,
		CheckInRewardsCreated: rewardCreated,
	}, nil
}
