package logic

import (
	"errors"

	userbiz "backend/internal/biz/user"
	"backend/rpc/internal/errorx"
)

func mapUserBizErr(err error) error {
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, userbiz.ErrNotFound):
		return errorx.NotFound("用户不存在")
	case errors.Is(err, userbiz.ErrUnauthorized):
		msg := err.Error()
		if msg == userbiz.ErrUnauthorized.Error() {
			msg = "用户名或密码错误"
		}
		return errorx.New(401, msg)
	case errors.Is(err, userbiz.ErrAlreadyExists):
		return errorx.AlreadyExists("用户已存在")
	case errors.Is(err, userbiz.ErrInvalidArgument):
		return errorx.InvalidArgument("参数无效")
	case errors.Is(err, userbiz.ErrWrongPassword):
		return errorx.InvalidArgument("旧密码不正确")
	case errors.Is(err, userbiz.ErrInsufficientBalance):
		return errorx.New(400, "余额不足，请先充值")
	case errors.Is(err, userbiz.ErrVipPlanNotFound):
		return errorx.NotFound("VIP套餐不存在")
	case errors.Is(err, userbiz.ErrTransactionNotFound):
		return errorx.NotFound("交易记录不存在")
	case errors.Is(err, userbiz.ErrNoActiveVip):
		return errorx.NotFound("用户没有活跃的VIP记录")
	case errors.Is(err, userbiz.ErrOAuthDisabled):
		return errorx.New(503, "飞书/微信功能未启用")
	default:
		return errorx.Internal("用户操作失败")
	}
}
