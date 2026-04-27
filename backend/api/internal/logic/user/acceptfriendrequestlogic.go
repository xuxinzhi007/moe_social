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

type AcceptFriendRequestLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAcceptFriendRequestLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AcceptFriendRequestLogic {
	return &AcceptFriendRequestLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AcceptFriendRequestLogic) AcceptFriendRequest(req *types.FriendRequestActionReq) (resp *types.FriendRequestActionResp, err error) {
	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.AcceptFriendRequest(l.ctx, &super.AcceptFriendRequestReq{
		ActorUserId: req.UserId,
		RequestId:   req.RequestId,
	})

	if err != nil {
		l.Errorf("[好友] 接受好友请求：调用服务失败 错误=%v", err)
		return &types.FriendRequestActionResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 构建响应
	resp = &types.FriendRequestActionResp{
		BaseResp: common.HandleRPCError(nil, "好友请求已接受"),
		Data:     rpcResp.Ok,
	}

	return resp, nil
}
