package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type CheckFollowLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewCheckFollowLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CheckFollowLogic {
	return &CheckFollowLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CheckFollowLogic) CheckFollow(req *types.CheckFollowReq) (resp *types.CheckFollowResp, err error) {
	l.Debug("检查关注状态请求:", req)

	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.CheckFollow(l.ctx, &super.CheckFollowReq{
		FollowerId:  req.FollowerId,
		FollowingId: req.FollowingId,
	})

	if err != nil {
		l.Error("调用检查关注状态RPC服务失败:", err)
		return &types.CheckFollowResp{
			BaseResp: common.HandleError(err),
			Data:     false,
		}, nil
	}

	l.Debug("检查关注状态结果:", req.FollowerId, "是否关注", req.FollowingId, "：", rpcResp.IsFollowing)

	return &types.CheckFollowResp{
		BaseResp: common.HandleError(nil),
		Data:     rpcResp.IsFollowing,
	}, nil
}
