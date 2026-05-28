package logic

import (
	"context"
	"errors"

	commentapp "backend/internal/service/comment"
	commentbiz "backend/internal/biz/comment"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type LikeCommentLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewLikeCommentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *LikeCommentLogic {
	return &LikeCommentLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *LikeCommentLogic) LikeComment(in *moe.LikeCommentReq) (*moe.LikeCommentResp, error) {
	app := commentapp.New(l.svcCtx.DB)
	resp, err := app.LikeComment(l.ctx, in)
	if err != nil {
		switch {
		case errors.Is(err, commentbiz.ErrInvalidCommentID):
			return nil, errors.New("invalid comment_id")
		case errors.Is(err, commentbiz.ErrInvalidUserID):
			return nil, errors.New("invalid user_id")
		case errors.Is(err, commentbiz.ErrCommentNotFound):
			return nil, errors.New("comment not found")
		default:
			l.Error("点赞评论失败:", err)
			return nil, err
		}
	}
	return resp, nil
}
