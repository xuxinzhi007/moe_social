package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateLevelConfigLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateLevelConfigLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateLevelConfigLogic {
	return &AdminUpdateLevelConfigLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpdateLevelConfigLogic) AdminUpdateLevelConfig(in *moe.AdminUpdateLevelConfigReq) (*moe.AdminUpdateLevelConfigResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).UpdateLevelConfig(l.ctx, in)
	if err != nil {
		return nil, mapAdminGrowthErr(err)
	}
	return resp, nil
}
