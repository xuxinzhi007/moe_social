package common

import (
	"errors"

	userbiz "backend/internal/biz/user"
	"backend/internal/legacy/types"
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
	var conflict *userbiz.ConflictError
	if errors.As(err, &conflict) {
		return types.BaseResp{Success: false, Message: conflict.Message}
	}
	if errors.Is(err, userbiz.ErrMoeNoNotFound) {
		return types.BaseResp{Success: false, Message: "未找到该 Moe 号"}
	}
	if errors.Is(err, userbiz.ErrFriendTargetRequired) {
		return types.BaseResp{Success: false, Message: "请填写 to_user_id 或 to_moe_no"}
	}
	if errors.Is(err, userbiz.ErrFriendSelf) {
		return types.BaseResp{Success: false, Message: "不能向自己发起申请"}
	}
	if errors.Is(err, userbiz.ErrFriendRequestNotFound) {
		return types.BaseResp{Success: false, Message: "申请不存在"}
	}
	if errors.Is(err, userbiz.ErrFriendRequestInvalid) {
		return types.BaseResp{Success: false, Message: "无法处理该申请"}
	}
	return HandleRPCError(err, "")
}
