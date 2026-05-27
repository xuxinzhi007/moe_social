package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateUserLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateUserLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateUserLogic {
	return &AdminUpdateUserLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpdateUserLogic) AdminUpdateUser(in *super.AdminUpdateUserReq) (*super.AdminUpdateUserResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).UpdateUser(l.ctx, in)
	if err != nil {
		return nil, mapAdminUserWriteErr(err)
	}
	return resp, nil
}
