package logic

import (
	"context"

	"backend/rpc/rpc/internal/svc"
	"backend/rpc/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserCountLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserCountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserCountLogic {
	return &GetUserCountLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserCountLogic) GetUserCount(in *rpc.GetUserCountReq) (*rpc.GetUserCountResp, error) {
	// todo: add your logic here and delete this line

	return &rpc.GetUserCountResp{}, nil
}
