package usergrpc

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errUserAppNil = status.Error(codes.FailedPrecondition, "UserApp 未初始化")
