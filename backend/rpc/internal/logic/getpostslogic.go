package logic

import (
	"context"

	postbiz "backend/internal/biz/post"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetPostsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetPostsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetPostsLogic {
	return &GetPostsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetPostsLogic) GetPosts(in *moe.GetPostsReq) (*moe.GetPostsResp, error) {
	posts, total, err := postbiz.List(l.ctx, l.svcCtx.DB, postbiz.ListFilter{
		Page: in.GetPage(), PageSize: in.GetPageSize(), ViewerUserID: in.GetViewerUserId(),
		FeedMode: in.GetFeedMode(), TopicTagID: in.GetTopicTagId(), AuthorUserID: in.GetAuthorUserId(),
	})
	if err != nil {
		return nil, err
	}
	return &moe.GetPostsResp{Posts: posts, Total: total}, nil
}
