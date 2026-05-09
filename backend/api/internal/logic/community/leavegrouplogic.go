package community

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type LeaveGroupLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewLeaveGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *LeaveGroupLogic {
	return &LeaveGroupLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *LeaveGroupLogic) LeaveGroup(req *types.LeaveGroupReq) (resp *types.BaseResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.LeaveGroup(l.ctx, &super.LeaveGroupReq{
		GroupId: req.GroupId,
		UserId:  req.UserId,
	})
	if err != nil {
		return &types.BaseResp{
			Code:    1,
			Message: err.Error(),
			Success: false,
		}, nil
	}

	return &types.BaseResp{
		Code:    0,
		Message: rpcResp.Message,
		Success: rpcResp.Success,
	}, nil
}
