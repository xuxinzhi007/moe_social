package grpcserver

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errMoeAdminNil = status.Error(codes.FailedPrecondition, "MoeAdmin 未初始化")
