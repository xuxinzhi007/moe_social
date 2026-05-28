package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

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

func (l *AdminBootstrapLevelsLogic) AdminBootstrapLevels(in *moe.AdminBootstrapLevelsReq) (*moe.AdminBootstrapLevelsResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).BootstrapLevels(l.ctx, in)
	if err != nil {
		return nil, mapAdminGrowthErr(err)
	}
	return resp, nil
}
