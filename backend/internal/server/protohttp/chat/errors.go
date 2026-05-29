package chathttp

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errChatAppNil = status.Error(codes.FailedPrecondition, "ChatApp 未初始化")
