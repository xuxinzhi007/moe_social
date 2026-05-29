package commentgrpc

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errCommentAppNil = status.Error(codes.FailedPrecondition, "CommentApp 未初始化")
