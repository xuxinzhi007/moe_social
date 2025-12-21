package logic

import (
	"context"

	"backend/rpc/rpc/internal/svc"
	"backend/rpc/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateVipOrderLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreateVipOrderLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateVipOrderLogic {
	return &CreateVipOrderLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// VIP订单相关服务
func (l *CreateVipOrderLogic) CreateVipOrder(in *rpc.CreateVipOrderReq) (*rpc.CreateVipOrderResp, error) {
	// todo: add your logic here and delete this line

	return &rpc.CreateVipOrderResp{}, nil
}
