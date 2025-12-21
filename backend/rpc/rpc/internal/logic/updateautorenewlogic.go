package logic

import (
	"context"

	"backend/rpc/rpc/internal/svc"
	"backend/rpc/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateAutoRenewLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpdateAutoRenewLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateAutoRenewLogic {
	return &UpdateAutoRenewLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpdateAutoRenewLogic) UpdateAutoRenew(in *rpc.UpdateAutoRenewReq) (*rpc.UpdateAutoRenewResp, error) {
	// todo: add your logic here and delete this line

	return &rpc.UpdateAutoRenewResp{}, nil
}
