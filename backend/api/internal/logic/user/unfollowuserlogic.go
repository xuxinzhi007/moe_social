package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UnfollowUserLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewUnfollowUserLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UnfollowUserLogic {
	return &UnfollowUserLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UnfollowUserLogic) UnfollowUser(req *types.UnfollowUserReq) (resp *types.FollowUserResp, err error) {
	l.Debug("取消关注请求:", req)

	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.UnfollowUser(l.ctx, &super.UnfollowUserReq{
		UserId:      req.UserId,
		FollowingId: req.FollowingId,
	})

	if err != nil {
		l.Error("调用取消关注用户RPC服务失败:", err)
		return &types.FollowUserResp{
			BaseResp: common.HandleError(err),
			Data:     false,
		}, nil
	}

	l.Debug("取消关注成功:", req.UserId, "取消关注了", req.FollowingId)

	return &types.FollowUserResp{
		BaseResp: common.HandleError(nil),
		Data:     rpcResp.Success,
	}, nil
}
