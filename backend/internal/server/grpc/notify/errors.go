package notifygrpc

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errNotifyAppNil = status.Error(codes.FailedPrecondition, "NotifyApp 未初始化")
