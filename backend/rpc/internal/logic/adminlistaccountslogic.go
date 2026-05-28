package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListAccountsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListAccountsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAccountsLogic {
	return &AdminListAccountsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListAccountsLogic) AdminListAccounts(in *super.AdminListAccountsReq) (*super.AdminListAccountsResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).ListAccounts(l.ctx, in)
	if err != nil {
		return nil, mapAdminAccountErr(err)
	}
	return resp, nil
}
