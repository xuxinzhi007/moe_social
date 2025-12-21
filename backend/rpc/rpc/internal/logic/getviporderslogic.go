package logic

import (
	"context"

	"backend/rpc/rpc/internal/svc"
	"backend/rpc/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipOrdersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetVipOrdersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipOrdersLogic {
	return &GetVipOrdersLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetVipOrdersLogic) GetVipOrders(in *rpc.GetVipOrdersReq) (*rpc.GetVipOrdersResp, error) {
	// todo: add your logic here and delete this line

	return &rpc.GetVipOrdersResp{}, nil
}
