package logic

import (
	"errors"

	userbiz "backend/internal/biz/user"
	"backend/rpc/internal/errorx"
)

func mapFriendBizErr(err error) error {
	if err == nil {
		return nil
	}
	var conflict *userbiz.ConflictError
	if errors.As(err, &conflict) {
		return errorx.AlreadyExists(conflict.Message)
	}
	switch {
	case errors.Is(err, userbiz.ErrUnauthorized):
		return errorx.Unauthenticated("请先登录")
	case errors.Is(err, userbiz.ErrMoeNoNotFound):
		return errorx.NotFound("未找到该 Moe 号")
	case errors.Is(err, userbiz.ErrNotFound):
		return errorx.NotFound("用户不存在")
	case errors.Is(err, userbiz.ErrFriendTargetRequired):
		return errorx.InvalidArgument("请填写 to_user_id 或 to_moe_no")
	case errors.Is(err, userbiz.ErrFriendSelf):
		return errorx.InvalidArgument("不能向自己发起申请")
	case errors.Is(err, userbiz.ErrInvalidArgument):
		return errorx.InvalidArgument("无效的用户 ID")
	case errors.Is(err, userbiz.ErrFriendRequestNotFound):
		return errorx.NotFound("申请不存在")
	case errors.Is(err, userbiz.ErrFriendRequestInvalid):
		return errorx.InvalidArgument("无法处理该申请")
	default:
		return errorx.Internal("服务器内部错误")
	}
}
