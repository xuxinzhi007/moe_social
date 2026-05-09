package community

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateGroupLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewUpdateGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateGroupLogic {
	return &UpdateGroupLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UpdateGroupLogic) UpdateGroup(req *types.UpdateGroupReq) (resp *types.UpdateGroupResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.UpdateGroup(l.ctx, &super.UpdateGroupReq{
		GroupId:    req.GroupId,
		Name:       req.Name,
		Description: req.Description,
		Avatar:     req.Avatar,
		Cover:      req.Cover,
		IsPublic:   req.IsPublic,
	})
	if err != nil {
		return nil, err
	}

	return &types.UpdateGroupResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: rpcResp.Message,
			Success: rpcResp.Success,
		},
	}, nil
}
