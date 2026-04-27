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

type ListIncomingFriendRequestsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewListIncomingFriendRequestsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListIncomingFriendRequestsLogic {
	return &ListIncomingFriendRequestsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ListIncomingFriendRequestsLogic) ListIncomingFriendRequests(req *types.FriendUserPathReq) (resp *types.ListFriendRequestsResp, err error) {
	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.ListIncomingFriendRequests(l.ctx, &super.ListIncomingFriendRequestsReq{
		ActorUserId: req.UserId,
	})

	if err != nil {
		l.Errorf("[好友] 获取收到的好友请求：调用服务失败 错误=%v", err)
		return &types.ListFriendRequestsResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 构建响应
	resp = &types.ListFriendRequestsResp{
		BaseResp: common.HandleRPCError(nil, "获取好友请求成功"),
		Data:     make([]types.FriendRequestView, 0, len(rpcResp.Data)),
	}

	// 转换为API响应
	for _, reqData := range rpcResp.Data {
		reqView := types.FriendRequestView{
			Id: reqData.Id,
			FromUser: types.User{
				Id:              reqData.FromUser.Id,
				Username:        reqData.FromUser.Username,
				Email:           reqData.FromUser.Email,
				MoeNo:           reqData.FromUser.MoeNo,
				Avatar:          reqData.FromUser.Avatar,
				Signature:       reqData.FromUser.Signature,
				Gender:          reqData.FromUser.Gender,
				Birthday:        reqData.FromUser.Birthday,
				CreatedAt:       reqData.FromUser.CreatedAt,
				UpdatedAt:       reqData.FromUser.UpdatedAt,
				IsVip:           reqData.FromUser.IsVip,
				VipExpiresAt:    reqData.FromUser.VipExpiresAt,
				AutoRenew:       reqData.FromUser.AutoRenew,
				Balance:         float64(reqData.FromUser.Balance),
				Inventory:       reqData.FromUser.Inventory,
				EquippedFrameId: reqData.FromUser.EquippedFrameId,
			},
			ToUser: types.User{
				Id:              reqData.ToUser.Id,
				Username:        reqData.ToUser.Username,
				Email:           reqData.ToUser.Email,
				MoeNo:           reqData.ToUser.MoeNo,
				Avatar:          reqData.ToUser.Avatar,
				Signature:       reqData.ToUser.Signature,
				Gender:          reqData.ToUser.Gender,
				Birthday:        reqData.ToUser.Birthday,
				CreatedAt:       reqData.ToUser.CreatedAt,
				UpdatedAt:       reqData.ToUser.UpdatedAt,
				IsVip:           reqData.ToUser.IsVip,
				VipExpiresAt:    reqData.ToUser.VipExpiresAt,
				AutoRenew:       reqData.ToUser.AutoRenew,
				Balance:         float64(reqData.ToUser.Balance),
				Inventory:       reqData.ToUser.Inventory,
				EquippedFrameId: reqData.ToUser.EquippedFrameId,
			},
			Status:    reqData.Status,
			CreatedAt: reqData.CreatedAt,
		}

		resp.Data = append(resp.Data, reqView)
	}

	return resp, nil
}
