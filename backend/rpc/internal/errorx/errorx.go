package errorx

import (
	"backend/common/errorcode"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// New 创建一个带有 HTTP 状态码的 gRPC 错误
func New(httpCode int, message string) error {
	var code codes.Code
	
	switch httpCode {
	case errorcode.E_INVALID_PARAM:
		code = codes.InvalidArgument
	case errorcode.E_UNAUTHORIZED:
		code = codes.Unauthenticated
	case errorcode.E_FORBIDDEN:
		code = codes.PermissionDenied
	case errorcode.E_NOT_FOUND:
		code = codes.NotFound
	case errorcode.E_CONFLICT:
		code = codes.AlreadyExists
	case errorcode.E_INTERNAL_ERROR:
		code = codes.Internal
	case errorcode.E_SERVICE_UNAVAILABLE:
		code = codes.Unavailable
	default:
		code = codes.Unknown
	}
	
	return status.Error(code, message)
}

// Internal 创建一个内部错误（500）
func Internal(message string) error {
	return status.Error(codes.Internal, message)
}

// NotFound 创建一个未找到错误（404）
func NotFound(message string) error {
	return status.Error(codes.NotFound, message)
}

// InvalidArgument 创建一个无效参数错误（400）
func InvalidArgument(message string) error {
	return status.Error(codes.InvalidArgument, message)
}

// Unauthenticated 创建一个未认证错误（401）
func Unauthenticated(message string) error {
	return status.Error(codes.Unauthenticated, message)
}

// AlreadyExists 创建一个已存在错误（409）
func AlreadyExists(message string) error {
	return status.Error(codes.AlreadyExists, message)
}
