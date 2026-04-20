package community

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteGroupLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewDeleteGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteGroupLogic {
	return &DeleteGroupLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *DeleteGroupLogic) DeleteGroup(req *types.DeleteGroupReq) (resp *types.BaseResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.DeleteGroup(l.ctx, &super.DeleteGroupReq{
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
