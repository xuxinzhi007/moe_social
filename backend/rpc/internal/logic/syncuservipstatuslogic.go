package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type SyncUserVipStatusLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewSyncUserVipStatusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SyncUserVipStatusLogic {
	return &SyncUserVipStatusLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *SyncUserVipStatusLogic) SyncUserVipStatus(in *moe.SyncUserVipStatusReq) (*moe.SyncUserVipStatusResp, error) {
	resp, err := userapp.New(l.svcCtx.DB).SyncUserVipStatus(l.ctx, in)
	return resp, mapUserBizErr(err)
}
