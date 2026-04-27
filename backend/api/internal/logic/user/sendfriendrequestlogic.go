// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type SendFriendRequestLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewSendFriendRequestLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SendFriendRequestLogic {
	return &SendFriendRequestLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *SendFriendRequestLogic) SendFriendRequest(req *types.SendFriendRequestReq) (resp *types.SendFriendRequestResp, err error) {
	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.SendFriendRequest(l.ctx, &super.SendFriendRequestReq{
		ActorUserId: req.UserId,
		ToUserId:    req.ToUserId,
		ToMoeNo:     req.ToMoeNo,
	})

	if err != nil {
		l.Errorf("[好友] 发送好友请求：调用服务失败 错误=%v", err)
		return &types.SendFriendRequestResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 构建响应
	resp = &types.SendFriendRequestResp{
		BaseResp: common.HandleRPCError(nil, "好友请求发送成功"),
	}

	// 转换为API响应
	if rpcResp.Data != nil {
		resp.Data = types.FriendRequestView{
			Id: rpcResp.Data.Id,
			FromUser: types.User{
				Id:              rpcResp.Data.FromUser.Id,
				Username:        rpcResp.Data.FromUser.Username,
				Email:           rpcResp.Data.FromUser.Email,
				MoeNo:           rpcResp.Data.FromUser.MoeNo,
				Avatar:          rpcResp.Data.FromUser.Avatar,
				Signature:       rpcResp.Data.FromUser.Signature,
				Gender:          rpcResp.Data.FromUser.Gender,
				Birthday:        rpcResp.Data.FromUser.Birthday,
				CreatedAt:       rpcResp.Data.FromUser.CreatedAt,
				UpdatedAt:       rpcResp.Data.FromUser.UpdatedAt,
				IsVip:           rpcResp.Data.FromUser.IsVip,
				VipExpiresAt:    rpcResp.Data.FromUser.VipExpiresAt,
				AutoRenew:       rpcResp.Data.FromUser.AutoRenew,
				Balance:         float64(rpcResp.Data.FromUser.Balance),
				Inventory:       rpcResp.Data.FromUser.Inventory,
				EquippedFrameId: rpcResp.Data.FromUser.EquippedFrameId,
			},
			ToUser: types.User{
				Id:              rpcResp.Data.ToUser.Id,
				Username:        rpcResp.Data.ToUser.Username,
				Email:           rpcResp.Data.ToUser.Email,
				MoeNo:           rpcResp.Data.ToUser.MoeNo,
				Avatar:          rpcResp.Data.ToUser.Avatar,
				Signature:       rpcResp.Data.ToUser.Signature,
				Gender:          rpcResp.Data.ToUser.Gender,
				Birthday:        rpcResp.Data.ToUser.Birthday,
				CreatedAt:       rpcResp.Data.ToUser.CreatedAt,
				UpdatedAt:       rpcResp.Data.ToUser.UpdatedAt,
				IsVip:           rpcResp.Data.ToUser.IsVip,
				VipExpiresAt:    rpcResp.Data.ToUser.VipExpiresAt,
				AutoRenew:       rpcResp.Data.ToUser.AutoRenew,
				Balance:         float64(rpcResp.Data.ToUser.Balance),
				Inventory:       rpcResp.Data.ToUser.Inventory,
				EquippedFrameId: rpcResp.Data.ToUser.EquippedFrameId,
			},
			Status:    rpcResp.Data.Status,
			CreatedAt: rpcResp.Data.CreatedAt,
		}
	}

	return resp, nil
}
