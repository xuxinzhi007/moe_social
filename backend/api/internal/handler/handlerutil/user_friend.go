package handlerutil

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"backend/utils"
)

// BearerUserID 从 Authorization Bearer token 解析用户 ID。
func BearerUserID(r *http.Request) (uint, error) {
	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	if strings.HasPrefix(auth, "Bearer ") {
		auth = strings.TrimSpace(strings.TrimPrefix(auth, "Bearer "))
	}
	if auth == "" {
		return 0, errors.New("unauthorized")
	}
	cl, err := utils.ParseToken(auth)
	if err != nil {
		return 0, err
	}
	return cl.UserID, nil
}

// ParsePathUint 解析路径中的 uint ID。
func ParsePathUint(s string) (uint, error) {
	v, err := strconv.ParseUint(strings.TrimSpace(s), 10, 64)
	if err != nil {
		return 0, err
	}
	return uint(v), nil
}

// ActorString uint 用户 ID → 十进制字符串。
func ActorString(me uint) string {
	return strconv.FormatUint(uint64(me), 10)
}

// FriendViewFromRPC proto FriendRequestView → API types。
func FriendViewFromRPC(v *moe.FriendRequestView) types.FriendRequestView {
	if v == nil {
		return types.FriendRequestView{}
	}
	return types.FriendRequestView{
		Id: v.Id, FromUser: common.RpcUserToTypes(v.FromUser), ToUser: common.RpcUserToTypes(v.ToUser),
		Status: v.Status, CreatedAt: v.CreatedAt,
	}
}
