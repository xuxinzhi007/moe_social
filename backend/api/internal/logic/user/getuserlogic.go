package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetUserLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserLogic {
	return &GetUserLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetUserLogic) GetUser(req *types.GetUserReq) (resp *types.GetUserResp, err error) {
	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.GetUser(l.ctx, &rpc.GetUserReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.GetUserResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 转换为API响应
	return &types.GetUserResp{
		BaseResp: common.HandleRPCError(nil, "获取用户信息成功"),
		Data: types.User{
			Id:           rpcResp.User.Id,
			Username:     rpcResp.User.Username,
			Email:        rpcResp.User.Email,
			Avatar:       rpcResp.User.Avatar,
			CreatedAt:    rpcResp.User.CreatedAt,
			UpdatedAt:    rpcResp.User.UpdatedAt,
			IsVip:        rpcResp.User.IsVip,
			VipExpiresAt: rpcResp.User.VipExpiresAt,
			AutoRenew:    rpcResp.User.AutoRenew,
		},
	}, nil
}
