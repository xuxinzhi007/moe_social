package common

import (
	"errors"

	landingbiz "backend/internal/biz/landing"
	"backend/internal/legacy/types"
)

// HandleLandingGWError landing biz / gRPC 错误转 BaseResp。
func HandleLandingGWError(err error, okMsg string) types.BaseResp {
	if err == nil {
		return HandleRPCError(nil, okMsg)
	}
	switch {
	case errors.Is(err, landingbiz.ErrInvalidEmail):
		return types.BaseResp{Success: false, Message: "请填写有效的联系邮箱"}
	case errors.Is(err, landingbiz.ErrInvalidArgument):
		return types.BaseResp{Success: false, Message: "反馈内容至少 5 个字"}
	case errors.Is(err, landingbiz.ErrTooLong):
		return types.BaseResp{Success: false, Message: "反馈内容不能超过 2000 字"}
	case errors.Is(err, landingbiz.ErrRateLimited):
		return types.BaseResp{Success: false, Message: "提交过于频繁，请稍后再试"}
	default:
		return HandleRPCError(err, "")
	}
}
