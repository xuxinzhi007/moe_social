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

type GetFriendStatusLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetFriendStatusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetFriendStatusLogic {
	return &GetFriendStatusLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetFriendStatusLogic) GetFriendStatus(req *types.FriendStatusPathReq) (resp *types.FriendStatusResp, err error) {
	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.GetFriendRelation(l.ctx, &super.GetFriendRelationReq{
		ActorUserId: req.UserId,
		OtherUserId: req.OtherUserId,
	})

	if err != nil {
		l.Errorf("[好友] 获取好友状态：调用服务失败 错误=%v", err)
		return &types.FriendStatusResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 构建响应
	resp = &types.FriendStatusResp{
		BaseResp: common.HandleRPCError(nil, "获取好友状态成功"),
		Data: types.FriendRelationData{
			Relation: rpcResp.Relation,
		},
	}

	return resp, nil
}
