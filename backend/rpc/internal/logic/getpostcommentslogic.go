package logic

import (
	"context"
	"errors"

	commentbiz "backend/internal/biz/comment"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetPostCommentsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetPostCommentsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetPostCommentsLogic {
	return &GetPostCommentsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *GetPostCommentsLogic) GetPostComments(in *super.GetPostCommentsReq) (*super.GetPostCommentsResp, error) {
	items, total, err := commentbiz.ListByPost(l.ctx, l.svcCtx.DB, commentbiz.ListFilter{
		PostID: in.GetPostId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
		ViewerUserID: in.GetViewerUserId(),
	})
	if err != nil {
		if errors.Is(err, commentbiz.ErrInvalidPostID) {
			return nil, err
		}
		l.Error("查询评论列表失败:", err)
		return nil, err
	}
	return &super.GetPostCommentsResp{Comments: items, Total: total}, nil
}
