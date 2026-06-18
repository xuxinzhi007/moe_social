package behaviorhttp

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errBehaviorAppNil = status.Error(codes.FailedPrecondition, "BehaviorApp 未初始化")
