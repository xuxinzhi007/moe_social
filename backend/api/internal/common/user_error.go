package common

import (
	"errors"

	userbiz "backend/internal/biz/user"
	"backend/api/internal/types"
)

// HandleUserGWError biz / 网关 / gRPC 错误转 BaseResp。
func HandleUserGWError(err error, okMsg string) types.BaseResp {
	if err == nil {
		return HandleRPCError(nil, okMsg)
	}
	if errors.Is(err, userbiz.ErrNotFound) {
		return types.BaseResp{Success: false, Message: "用户不存在"}
	}
	if errors.Is(err, userbiz.ErrUnauthorized) {
		return types.BaseResp{Success: false, Message: "用户名或密码错误"}
	}
	if errors.Is(err, userbiz.ErrAlreadyExists) {
		return types.BaseResp{Success: false, Message: "用户名或邮箱已存在"}
	}
	if errors.Is(err, userbiz.ErrInvalidArgument) {
		return types.BaseResp{Success: false, Message: "参数无效"}
	}
	return HandleRPCError(err, "")
}
