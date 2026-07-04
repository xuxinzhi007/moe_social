package platformhttp

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var (
	errPlatformUnavailable = status.Error(codes.FailedPrecondition, "platform dependencies not initialized")
	errLLMAppNil           = status.Error(codes.FailedPrecondition, "LLMApp not initialized")
	errUnauthorized        = status.Error(codes.Unauthenticated, "unauthorized")
)
