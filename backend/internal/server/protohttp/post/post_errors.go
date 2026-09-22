package posthttp

import (
	"errors"

	postbiz "backend/internal/biz/post"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errPostAppNil = status.Error(codes.FailedPrecondition, "PostApp 未初始化")

func mapPostError(err error) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, postbiz.ErrEmptyPostContent):
		return status.Error(codes.InvalidArgument, "写点文字、选几张图，或画一张手绘卡片再发布吧")
	case errors.Is(err, postbiz.ErrInvalidGroupID):
		return status.Error(codes.InvalidArgument, "群组参数无效")
	case errors.Is(err, postbiz.ErrGroupNotFound):
		return status.Error(codes.NotFound, "群组不存在")
	case errors.Is(err, postbiz.ErrNotGroupMember):
		return status.Error(codes.PermissionDenied, "请先加入该群组再发帖")
	case errors.Is(err, postbiz.ErrUserNotFound):
		return status.Error(codes.NotFound, "用户不存在")
	case errors.Is(err, postbiz.ErrEmptyUserID), errors.Is(err, postbiz.ErrInvalidUserID):
		return status.Error(codes.Unauthenticated, "请先登录")
	case errors.Is(err, postbiz.ErrPostNotFound):
		return status.Error(codes.NotFound, "帖子不存在")
	case errors.Is(err, postbiz.ErrNotPostOwner):
		return status.Error(codes.PermissionDenied, "只能操作自己的帖子")
	case errors.Is(err, postbiz.ErrEmptyReason):
		return status.Error(codes.InvalidArgument, "请填写举报原因")
	case errors.Is(err, postbiz.ErrEmptyReporterID):
		return status.Error(codes.Unauthenticated, "请先登录")
	default:
		return err
	}
}
