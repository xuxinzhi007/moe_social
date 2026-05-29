package viphttp

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errVipAppNil = status.Error(codes.FailedPrecondition, "UserApp(Vip) 未初始化")
