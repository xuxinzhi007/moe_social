package posthttp

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errPostAppNil = status.Error(codes.FailedPrecondition, "PostApp 未初始化")
