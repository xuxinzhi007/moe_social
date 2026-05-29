package aihttp

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errAIAppNil = status.Error(codes.FailedPrecondition, "AIApp 未初始化")
