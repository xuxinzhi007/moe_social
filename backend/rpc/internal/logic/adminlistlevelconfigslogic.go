package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListLevelConfigsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListLevelConfigsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListLevelConfigsLogic {
	return &AdminListLevelConfigsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListLevelConfigsLogic) AdminListLevelConfigs(in *moe.AdminListLevelConfigsReq) (*moe.AdminListLevelConfigsResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).ListLevelConfigs(l.ctx, in)
	if err != nil {
		return nil, mapAdminGrowthErr(err)
	}
	return resp, nil
}
