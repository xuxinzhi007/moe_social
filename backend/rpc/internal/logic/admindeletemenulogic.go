package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteMenuLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteMenuLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteMenuLogic {
	return &AdminDeleteMenuLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteMenuLogic) AdminDeleteMenu(in *moe.AdminDeleteMenuReq) (*moe.AdminDeleteMenuResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).DeleteMenu(l.ctx, in)
	if err != nil {
		return nil, mapAdminMenuDeleteErr(err)
	}
	return resp, nil
}
