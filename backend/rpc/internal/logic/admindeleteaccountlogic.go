package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteAccountLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteAccountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteAccountLogic {
	return &AdminDeleteAccountLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteAccountLogic) AdminDeleteAccount(in *super.AdminDeleteAccountReq) (*super.AdminDeleteAccountResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).DeleteAccount(l.ctx, in)
	if err != nil {
		return nil, mapAdminAccountErr(err)
	}
	return resp, nil
}
