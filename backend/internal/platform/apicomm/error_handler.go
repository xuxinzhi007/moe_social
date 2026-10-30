package apicomm

import (
	"backend/common/errorcode"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// BaseResp 通用基礎响应信封。
type BaseResp struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Success bool   `json:"success"`
}

// HandleRPCError 处理 RPC 错误并转换为 API 响应。
func HandleRPCError(err error, successMessage string) BaseResp {
	if err == nil {
		return BaseResp{
			Code:    errorcode.E_SUCCESS,
			Message: successMessage,
			Success: true,
		}
	}

	st, ok := status.FromError(err)
	if !ok {
		return BaseResp{
			Code:    errorcode.E_INTERNAL_ERROR,
			Message: "服务调用失败: " + err.Error(),
			Success: false,
		}
	}

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

	return BaseResp{
		Code:    httpCode,
		Message: st.Message(),
		Success: false,
	}
}

// HandleError 处理普通错误并转换为 API 响应。
func HandleError(err error) BaseResp {
	if err == nil {
		return BaseResp{
			Code:    errorcode.E_SUCCESS,
			Message: "操作成功",
			Success: true,
		}
	}

	return BaseResp{
		Code:    errorcode.E_INTERNAL_ERROR,
		Message: err.Error(),
		Success: false,
	}
}
