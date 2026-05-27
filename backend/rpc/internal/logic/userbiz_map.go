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
		return errorx.New(401, "用户名或密码错误")
	case errors.Is(err, userbiz.ErrAlreadyExists):
		return errorx.AlreadyExists("用户已存在")
	case errors.Is(err, userbiz.ErrInvalidArgument):
		return errorx.InvalidArgument("参数无效")
	default:
		return errorx.Internal("用户操作失败")
	}
}
