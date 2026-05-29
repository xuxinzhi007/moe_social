package userbiz

import (
	userv1 "backend/api/user/v1"
	vipv1 "backend/api/vip/v1"
	"backend/model"
	"backend/rpc/pb/moe"
)

// ModelToUserV1 将数据库用户转为 user.v1 User。
func ModelToUserV1(user *model.User) *userv1.User {
	return userv1.UserFromMoe(ModelToProto(user))
}

// LoginRespV1 登录响应。
func LoginRespV1(user model.User, token string) *userv1.LoginResp {
	return &userv1.LoginResp{User: ModelToUserV1(&user), Token: token}
}

// RegisterRespV1 注册响应。
func RegisterRespV1(user model.User, token string) *userv1.RegisterResp {
	return &userv1.RegisterResp{User: ModelToUserV1(&user), Token: token}
}

// UserInfoRespV1 用户信息响应。
func UserInfoRespV1(user model.User) *userv1.GetUserInfoResp {
	return &userv1.GetUserInfoResp{User: ModelToUserV1(&user)}
}

// GetUserRespV1 用户详情响应。
func GetUserRespV1(user model.User) *userv1.GetUserResp {
	return &userv1.GetUserResp{User: ModelToUserV1(&user)}
}

// GetUserVipStatusRespV1 VIP 状态响应。
func GetUserVipStatusRespV1(st VipStatus) *vipv1.GetUserVipStatusResp {
	return &vipv1.GetUserVipStatusResp{
		IsVip:     st.IsVip,
		ExpiresAt: st.ExpiresAt,
		AutoRenew: st.AutoRenew,
	}
}

// VipOrdersRespV1 VIP 订单列表响应。
func VipOrdersRespV1(orders []*moe.VipOrder, total int32) *vipv1.GetVipOrdersResp {
	return vipv1.GetVipOrdersRespFromMoe(&moe.GetVipOrdersResp{Orders: orders, Total: total})
}

// NotificationsRespV1 通知列表响应。
func NotificationsRespV1(items []*moe.Notification, total int32) *userv1.GetNotificationsResp {
	return userv1.GetNotificationsRespFromMoe(&moe.GetNotificationsResp{Notifications: items, Total: total})
}

// FollowingsRespV1 关注列表响应。
func FollowingsRespV1(users []*moe.User, total int32) *userv1.GetFollowingsResp {
	return userv1.GetFollowingsRespFromMoe(&moe.GetFollowingsResp{Users: users, Total: total})
}

// SendFriendRequestRespV1 好友申请响应。
func SendFriendRequestRespV1(view *moe.FriendRequestView) *userv1.SendFriendRequestResp {
	return userv1.SendFriendRequestRespFromMoe(&moe.SendFriendRequestResp{Data: view})
}

// ListIncomingFriendRequestsRespV1 收到的好友申请列表。
func ListIncomingFriendRequestsRespV1(data []*moe.FriendRequestView) *userv1.ListIncomingFriendRequestsResp {
	return userv1.ListIncomingFriendRequestsRespFromMoe(&moe.ListIncomingFriendRequestsResp{Data: data})
}

// ListOutgoingFriendRequestsRespV1 发出的好友申请列表。
func ListOutgoingFriendRequestsRespV1(data []*moe.FriendRequestView) *userv1.ListOutgoingFriendRequestsResp {
	return userv1.ListOutgoingFriendRequestsRespFromMoe(&moe.ListOutgoingFriendRequestsResp{Data: data})
}

// ListFriendsRespV1 好友列表响应。
func ListFriendsRespV1(users []*moe.User) *userv1.ListFriendsResp {
	return userv1.ListFriendsRespFromMoe(&moe.ListFriendsResp{Users: users})
}

// GetFriendRelationRespV1 好友关系响应。
func GetFriendRelationRespV1(relation string) *userv1.GetFriendRelationResp {
	return &userv1.GetFriendRelationResp{Relation: relation}
}

// FollowersRespV1 粉丝列表响应。
func FollowersRespV1(result FollowListResult) *userv1.GetFollowersResp {
	users := make([]*moe.User, 0, len(result.Users))
	for i := range result.Users {
		u := result.Users[i]
		users = append(users, ModelToProto(&u))
	}
	return userv1.GetFollowersRespFromMoe(&moe.GetFollowersResp{Users: users, Total: int32(result.Total)})
}
