package logic

import (
	"backend/model"
	userbiz "backend/internal/biz/user"
	"backend/rpc/pb/moe"
)

// modelUserToProto 将数据库用户转为 RPC User（含 moe_no）。
func modelUserToProto(user *model.User) *moe.User {
	return userbiz.ModelToProto(user)
}
