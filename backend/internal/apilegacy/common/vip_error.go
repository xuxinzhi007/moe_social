package common

import (
	"errors"

	vipbiz "backend/internal/biz/vip"
	"backend/internal/legacy/types"
)

// HandleVipError 将 biz / 网关错误转为 BaseResp。
func HandleVipError(err error, okMsg string) types.BaseResp {
	if err == nil {
		return HandleRPCError(nil, okMsg)
	}
	switch {
	case errors.Is(err, vipbiz.ErrNotFound):
		return types.BaseResp{Success: false, Message: "VIP 套餐不存在"}
	case errors.Is(err, vipbiz.ErrInvalidArgument):
		return types.BaseResp{Success: false, Message: "参数无效"}
	default:
		return types.BaseResp{Success: false, Message: "VIP 操作失败，请稍后重试"}
	}
}

// HandleVipGWError 兼容 in_process（biz）与 super RPC 回退错误。
func HandleVipGWError(err error, okMsg string) types.BaseResp {
	if err == nil {
		return HandleRPCError(nil, okMsg)
	}
	if errors.Is(err, vipbiz.ErrNotFound) || errors.Is(err, vipbiz.ErrInvalidArgument) {
		return HandleVipError(err, okMsg)
	}
	return HandleRPCError(err, "")
}
