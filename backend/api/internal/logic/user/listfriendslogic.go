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

type ListFriendsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewListFriendsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListFriendsLogic {
	return &ListFriendsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ListFriendsLogic) ListFriends(req *types.FriendUserPathReq) (resp *types.ListFriendsResp, err error) {
	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.ListFriends(l.ctx, &super.ListFriendsReq{
		ActorUserId: req.UserId,
	})

	if err != nil {
		l.Errorf("[好友] 获取好友列表：调用服务失败 错误=%v", err)
		return &types.ListFriendsResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 构建响应
	resp = &types.ListFriendsResp{
		BaseResp: common.HandleRPCError(nil, "获取好友列表成功"),
		Data:     make([]types.User, 0, len(rpcResp.Users)),
	}

	// 转换为API响应
	for _, userData := range rpcResp.Users {
		userView := types.User{
			Id:              userData.Id,
			Username:        userData.Username,
			Email:           userData.Email,
			MoeNo:           userData.MoeNo,
			Avatar:          userData.Avatar,
			Signature:       userData.Signature,
			Gender:          userData.Gender,
			Birthday:        userData.Birthday,
			CreatedAt:       userData.CreatedAt,
			UpdatedAt:       userData.UpdatedAt,
			IsVip:           userData.IsVip,
			VipExpiresAt:    userData.VipExpiresAt,
			AutoRenew:       userData.AutoRenew,
			Balance:         float64(userData.Balance),
			Inventory:       userData.Inventory,
			EquippedFrameId: userData.EquippedFrameId,
		}

		resp.Data = append(resp.Data, userView)
	}

	return resp, nil
}
