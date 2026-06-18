package vipreadhttp

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errVipAdminNil = status.Error(codes.FailedPrecondition, "VipAdmin 未初始化")
