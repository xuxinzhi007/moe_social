package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserCountLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetUserCountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserCountLogic {
	return &GetUserCountLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetUserCountLogic) GetUserCount(req *types.EmptyReq) (resp *types.GetUserCountResp, err error) {
	// 调用RPC服务获取用户总数
	rpcResp, err := l.svcCtx.SuperRpcClient.GetUserCount(l.ctx, &rpc.GetUserCountReq{})
	if err != nil {
		return &types.GetUserCountResp{
			BaseResp: common.HandleRPCError(err, ""),
			Data:     0,
		}, nil
	}

	return &types.GetUserCountResp{
		BaseResp: common.HandleRPCError(nil, "获取用户数量成功"),
		Data:     int(rpcResp.Count),
	}, nil
}
