package logic

import (
	"context"

	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetUserLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetUserLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetUserLogic {
	return &AdminGetUserLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminGetUserLogic) AdminGetUser(in *moe.AdminGetUserReq) (*moe.AdminGetUserResp, error) {
	resp, err := newAdminApp(l.svcCtx.DB).GetUser(l.ctx, in)
	if err != nil {
		return nil, mapAdminGetUserErr(err)
	}
	return resp, nil
}
