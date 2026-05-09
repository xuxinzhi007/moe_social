package community

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"

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
	return &types.GetGroupPostsResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "success",
			Success: true,
		},
		Data:  []types.GroupPost{},
		Total: 0,
	}, nil
}
