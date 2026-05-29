package checkingrpc

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errCheckinAppNil = status.Error(codes.FailedPrecondition, "CheckinApp 未初始化")
