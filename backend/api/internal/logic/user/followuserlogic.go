package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type FollowUserLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewFollowUserLogic(ctx context.Context, svcCtx *svc.ServiceContext) *FollowUserLogic {
	return &FollowUserLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *FollowUserLogic) FollowUser(req *types.FollowUserReq) (resp *types.FollowUserResp, err error) {
	l.Debug("关注用户请求:", req)

	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.FollowUser(l.ctx, &super.FollowUserReq{
		UserId:      req.UserId,
		FollowingId: req.FollowingId,
	})

	if err != nil {
		l.Error("调用关注用户RPC服务失败:", err)
		return &types.FollowUserResp{
			BaseResp: common.HandleError(err),
			Data:     false,
		}, nil
	}

	l.Debug("关注用户成功:", req.UserId, "关注了", req.FollowingId)

	return &types.FollowUserResp{
		BaseResp: common.HandleError(nil),
		Data:     rpcResp.Success,
	}, nil
}
