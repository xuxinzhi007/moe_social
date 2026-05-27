package logic

import (
	"context"
	"errors"

	commentapp "backend/internal/service/comment"
	commentbiz "backend/internal/biz/comment"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateCommentLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreateCommentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateCommentLogic {
	return &CreateCommentLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *CreateCommentLogic) CreateComment(in *super.CreateCommentReq) (*super.CreateCommentResp, error) {
	app := commentapp.New(l.svcCtx.DB)
	resp, err := app.CreateComment(l.ctx, in)
	if err != nil {
		switch {
		case errors.Is(err, commentbiz.ErrInvalidPostID):
			return nil, errors.New("invalid post_id")
		case errors.Is(err, commentbiz.ErrInvalidUserID):
			return nil, errors.New("invalid user_id")
		case errors.Is(err, commentbiz.ErrInvalidParentID):
			return nil, errors.New("invalid parent_id")
		case errors.Is(err, commentbiz.ErrParentNotFound):
			return nil, errors.New("parent comment not found")
		case errors.Is(err, commentbiz.ErrParentMismatch):
			return nil, errors.New("parent comment mismatch")
		default:
			l.Error("创建评论失败:", err)
			return nil, err
		}
	}
	return resp, nil
}
