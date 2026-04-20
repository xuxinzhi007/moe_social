package community

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type JoinGroupLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewJoinGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *JoinGroupLogic {
	return &JoinGroupLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *JoinGroupLogic) JoinGroup(req *types.JoinGroupReq) (resp *types.BaseResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.JoinGroup(l.ctx, &super.JoinGroupReq{
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
