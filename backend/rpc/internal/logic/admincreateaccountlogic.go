package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminCreateAccountLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminCreateAccountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCreateAccountLogic {
	return &AdminCreateAccountLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminCreateAccountLogic) AdminCreateAccount(in *moe.AdminCreateAccountReq) (*moe.AdminCreateAccountResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).CreateAccount(l.ctx, in)
	if err != nil {
		return nil, mapAdminAccountErr(err)
	}
	return resp, nil
}
