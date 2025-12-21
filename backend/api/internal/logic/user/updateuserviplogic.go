package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateUserVipLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewUpdateUserVipLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateUserVipLogic {
	return &UpdateUserVipLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UpdateUserVipLogic) UpdateUserVip(req *types.UpdateUserVipReq) (resp *types.UpdateUserVipResp, err error) {
	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.UpdateUserVip(l.ctx, &rpc.UpdateUserVipReq{
		UserId:     req.UserId,
		IsVip:      req.IsVip,
		VipExpires: req.VipExpires,
	})
	if err != nil {
		return &types.UpdateUserVipResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 转换为API响应
	return &types.UpdateUserVipResp{
		BaseResp: common.HandleRPCError(nil, "更新用户VIP状态成功"),
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
