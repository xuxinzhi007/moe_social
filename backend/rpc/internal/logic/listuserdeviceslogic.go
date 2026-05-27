package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListUserDevicesLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListUserDevicesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListUserDevicesLogic {
	return &ListUserDevicesLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *ListUserDevicesLogic) ListUserDevices(in *super.ListUserDevicesReq) (*super.ListUserDevicesResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).ListUserDevices(l.ctx, in)
	return resp, mapUserBizErr(err)
}
