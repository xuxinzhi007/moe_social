package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListUsersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListUsersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListUsersLogic {
	return &AdminListUsersLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListUsersLogic) AdminListUsers(in *super.AdminListUsersReq) (*super.AdminListUsersResp, error) {
	return adminapp.New(l.svcCtx.DB).ListUsers(l.ctx, in)
}
