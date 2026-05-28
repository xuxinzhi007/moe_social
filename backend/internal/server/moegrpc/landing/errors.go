package landinggrpc

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errLandingAppNil = status.Error(codes.FailedPrecondition, "LandingApp 未初始化")
