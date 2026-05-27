package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type SyncUserDeviceLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewSyncUserDeviceLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SyncUserDeviceLogic {
	return &SyncUserDeviceLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *SyncUserDeviceLogic) SyncUserDevice(in *super.SyncUserDeviceReq) (*super.SyncUserDeviceResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).SyncUserDevice(l.ctx, in)
	return resp, mapUserBizErr(err)
}
