package community

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateGroupPostLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewCreateGroupPostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateGroupPostLogic {
	return &CreateGroupPostLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CreateGroupPostLogic) CreateGroupPost(req *types.CreateGroupPostReq) (resp *types.CreateGroupPostResp, err error) {
	rpcResp, err := l.svcCtx.CommunityGW.CreateGroupPost(l.ctx, &moe.CreateGroupPostReq{
		GroupId: req.GroupId,
		PostId:  req.PostId,
		UserId:  req.UserId,
	})
	if err != nil {
		return nil, err
	}
	if !rpcResp.Success {
		return &types.CreateGroupPostResp{
			BaseResp: types.BaseResp{
				Code:    1,
				Message: rpcResp.Message,
				Success: false,
			},
		}, nil
	}

	return &types.CreateGroupPostResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: rpcResp.Message,
			Success: true,
		},
		Data: rpcGroupPostToTypes(rpcResp.GroupPost),
	}, nil
}
