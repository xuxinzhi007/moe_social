package communitygrpc

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errCommunityAppNil = status.Error(codes.FailedPrecondition, "CommunityApp 未初始化")
