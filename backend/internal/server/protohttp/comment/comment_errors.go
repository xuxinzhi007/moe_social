package commenthttp

import (
	"errors"

	commentbiz "backend/internal/biz/comment"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errCommentAppNil = status.Error(codes.FailedPrecondition, "CommentApp 未初始化")

func mapCommentError(err error) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, commentbiz.ErrInvalidPostID):
		return status.Error(codes.InvalidArgument, "帖子参数无效")
	case errors.Is(err, commentbiz.ErrInvalidUserID):
		return status.Error(codes.Unauthenticated, "请先登录")
	case errors.Is(err, commentbiz.ErrEmptyContent):
		return status.Error(codes.InvalidArgument, "请输入评论内容")
	case errors.Is(err, commentbiz.ErrPostNotFound):
		return status.Error(codes.NotFound, "帖子不存在")
	case errors.Is(err, commentbiz.ErrUserNotFound):
		return status.Error(codes.NotFound, "用户不存在")
	case errors.Is(err, commentbiz.ErrInvalidParentID):
		return status.Error(codes.InvalidArgument, "回复参数无效")
	case errors.Is(err, commentbiz.ErrParentNotFound):
		return status.Error(codes.NotFound, "要回复的评论不存在")
	case errors.Is(err, commentbiz.ErrParentMismatch):
		return status.Error(codes.InvalidArgument, "回复不属于当前帖子")
	case errors.Is(err, commentbiz.ErrInvalidCommentID):
		return status.Error(codes.InvalidArgument, "评论参数无效")
	case errors.Is(err, commentbiz.ErrCommentNotFound):
		return status.Error(codes.NotFound, "评论不存在")
	default:
		return err
	}
}
