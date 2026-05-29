package platformgrpc

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var (
	errSvcCtxNil    = status.Error(codes.FailedPrecondition, "ServiceContext 未初始化")
	errLLMAppNil    = status.Error(codes.FailedPrecondition, "LLMApp 未初始化")
	errUnauthorized = status.Error(codes.Unauthenticated, "unauthorized")
)
