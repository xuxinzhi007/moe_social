package community

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGroupPostsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetGroupPostsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGroupPostsLogic {
	return &GetGroupPostsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetGroupPostsLogic) GetGroupPosts(req *types.GetGroupPostsReq) (resp *types.GetGroupPostsResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.GetGroupPosts(l.ctx, &super.GetGroupPostsReq{
		GroupId:  req.GroupId,
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
		UserId:   req.UserId,
	})
	if err != nil {
		return nil, err
	}

	items := make([]types.GroupPost, 0, len(rpcResp.Posts))
	for _, gp := range rpcResp.Posts {
		items = append(items, rpcGroupPostToTypes(gp))
	}

	return &types.GetGroupPostsResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "success",
			Success: true,
		},
		Data:  items,
		Total: int(rpcResp.Total),
	}, nil
}
