package common

import (
	"backend/api/internal/types"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// HandleRPCError 处理 RPC 错误并转换为 API 响应
// 如果 err 为 nil，返回成功响应
// 如果 err 不为 nil，解析 gRPC 错误并返回对应的错误响应
func HandleRPCError(err error, successMessage string) types.BaseResp {
	if err == nil {
		return types.BaseResp{
			Code:    200,
			Message: successMessage,
			Success: true,
		}
	}

	// 解析 gRPC status 错误
	st, ok := status.FromError(err)
	if !ok {
		// 不是 gRPC 错误，返回通用错误
		return types.BaseResp{
			Code:    500,
			Message: "服务调用失败: " + err.Error(),
			Success: false,
		}
	}

	// 根据 gRPC 错误码映射 HTTP 状态码
	var httpCode int
	switch st.Code() {
	case codes.OK:
		httpCode = 200
	case codes.InvalidArgument:
		httpCode = 400
	case codes.Unauthenticated:
		httpCode = 401
	case codes.PermissionDenied:
		httpCode = 403
	case codes.NotFound:
		httpCode = 404
	case codes.AlreadyExists:
		httpCode = 409
	case codes.Internal:
		httpCode = 500
	default:
		httpCode = 500
	}

	return types.BaseResp{
		Code:    httpCode,
		Message: st.Message(),
		Success: false,
	}
}
