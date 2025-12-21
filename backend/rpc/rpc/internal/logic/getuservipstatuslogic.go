package logic

import (
	"context"

	"backend/rpc/rpc/internal/svc"
	"backend/rpc/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserVipStatusLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserVipStatusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserVipStatusLogic {
	return &GetUserVipStatusLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// VIP状态相关服务
func (l *GetUserVipStatusLogic) GetUserVipStatus(in *rpc.GetUserVipStatusReq) (*rpc.GetUserVipStatusResp, error) {
	// todo: add your logic here and delete this line

	return &rpc.GetUserVipStatusResp{}, nil
}
