package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserInfoLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetUserInfoLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserInfoLogic {
	return &GetUserInfoLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetUserInfoLogic) GetUserInfo(req *types.GetUserInfoReq) (resp *types.GetUserInfoResp, err error) {
	// 调用RPC服务获取用户信息
	rpcResp, err := l.svcCtx.SuperRpcClient.GetUserInfo(l.ctx, &rpc.GetUserInfoReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.GetUserInfoResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.GetUserInfoResp{
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
