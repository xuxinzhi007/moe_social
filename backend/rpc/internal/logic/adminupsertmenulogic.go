package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpsertMenuLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpsertMenuLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpsertMenuLogic {
	return &AdminUpsertMenuLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpsertMenuLogic) AdminUpsertMenu(in *super.AdminUpsertMenuReq) (*super.AdminUpsertMenuResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).UpsertMenu(l.ctx, in)
	if err != nil {
		return nil, mapAdminMenuWriteErr(err)
	}
	return resp, nil
}
