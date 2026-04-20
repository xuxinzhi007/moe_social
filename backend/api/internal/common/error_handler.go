package common

import (
	"backend/api/internal/types"
	"backend/common/errorcode"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// HandleRPCError 处理 RPC 错误并转换为 API 响应
// 如果 err 为 nil，返回成功响应
// 如果 err 不为 nil，解析 gRPC 错误并返回对应的错误响应
func HandleRPCError(err error, successMessage string) types.BaseResp {
	if err == nil {
		return types.BaseResp{
			Code:    errorcode.E_SUCCESS,
			Message: successMessage,
			Success: true,
		}
	}

	// 解析 gRPC status 错误
	st, ok := status.FromError(err)
	if !ok {
		// 不是 gRPC 错误，返回通用错误
		return types.BaseResp{
			Code:    errorcode.E_INTERNAL_ERROR,
			Message: "服务调用失败: " + err.Error(),
			Success: false,
		}
	}

	// 根据 gRPC 错误码映射 HTTP 状态码
	var httpCode int
	switch st.Code() {
	case codes.OK:
		httpCode = errorcode.E_SUCCESS
	case codes.InvalidArgument:
		httpCode = errorcode.E_INVALID_PARAM
	case codes.Unauthenticated:
		httpCode = errorcode.E_UNAUTHORIZED
	case codes.PermissionDenied:
		httpCode = errorcode.E_FORBIDDEN
	case codes.NotFound:
		httpCode = errorcode.E_NOT_FOUND
	case codes.AlreadyExists:
		httpCode = errorcode.E_CONFLICT
	case codes.Internal:
		httpCode = errorcode.E_INTERNAL_ERROR
	default:
		httpCode = errorcode.E_INTERNAL_ERROR
	}

	return types.BaseResp{
		Code:    httpCode,
		Message: st.Message(),
		Success: false,
	}
}

// HandleError 处理普通错误并转换为 API 响应
func HandleError(err error) types.BaseResp {
	if err == nil {
		return types.BaseResp{
			Code:    errorcode.E_SUCCESS,
			Message: "操作成功",
			Success: true,
		}
	}

	return types.BaseResp{
		Code:    errorcode.E_INTERNAL_ERROR,
		Message: err.Error(),
		Success: false,
	}
}
