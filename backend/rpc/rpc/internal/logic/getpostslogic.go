package logic

import (
	"context"

	"backend/rpc/rpc/internal/svc"
	"backend/rpc/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetPostsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetPostsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetPostsLogic {
	return &GetPostsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 帖子相关服务
func (l *GetPostsLogic) GetPosts(in *rpc.GetPostsReq) (*rpc.GetPostsResp, error) {
	// todo: add your logic here and delete this line

	return &rpc.GetPostsResp{}, nil
}
