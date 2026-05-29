package llmhttp

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errLLMAppNil = status.Error(codes.FailedPrecondition, "LLMApp 未初始化")
