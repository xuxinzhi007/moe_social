package logic

import (
	"errors"

	vipbiz "backend/internal/biz/vip"
	"backend/rpc/internal/errorx"
)

func mapVipBizErr(err error) error {
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, vipbiz.ErrNotFound):
		return errorx.NotFound("VIP 套餐不存在")
	case errors.Is(err, vipbiz.ErrInvalidArgument):
		return errorx.InvalidArgument("参数无效")
	default:
		return errorx.Internal("VIP 操作失败")
	}
}
