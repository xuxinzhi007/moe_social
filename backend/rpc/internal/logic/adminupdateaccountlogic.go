package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateAccountLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateAccountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateAccountLogic {
	return &AdminUpdateAccountLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpdateAccountLogic) AdminUpdateAccount(in *super.AdminUpdateAccountReq) (*super.AdminUpdateAccountResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).UpdateAccount(l.ctx, in)
	if err != nil {
		return nil, mapAdminAccountErr(err)
	}
	return resp, nil
}
