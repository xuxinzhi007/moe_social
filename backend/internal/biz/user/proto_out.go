package userbiz

import (
	notifyv1 "backend/api/notify/v1"
	userv1 "backend/api/user/v1"
	vipv1 "backend/api/vip/v1"
	"backend/model"
)

// ModelToVipUserV1 将数据库用户转为 vip.v1 User。
func ModelToVipUserV1(user *model.User) *vipv1.User {
	u := ModelToUserV1(user)
	if u == nil {
		return nil
	}
	return userV1ToVipV1(u)
}

func userV1ToVipV1(u *userv1.User) *vipv1.User {
	if u == nil {
		return nil
	}
	return &vipv1.User{
		Id:                     u.Id,
		Username:               u.Username,
		Email:                  u.Email,
		Avatar:                 u.Avatar,
		Signature:              u.Signature,
		Gender:                 u.Gender,
		Birthday:               u.Birthday,
		CreatedAt:              u.CreatedAt,
		UpdatedAt:              u.UpdatedAt,
		IsVip:                  u.IsVip,
		VipExpiresAt:           u.VipExpiresAt,
		AutoRenew:              u.AutoRenew,
		Balance:                u.Balance,
		Inventory:              u.Inventory,
		EquippedFrameId:        u.EquippedFrameId,
		MoeNo:                  u.MoeNo,
		GiftCharm:              u.GiftCharm,
		ReceivedGiftValue:      u.ReceivedGiftValue,
		DisplayUserId:          u.DisplayUserId,
		MessageRetentionChoice: u.MessageRetentionChoice,
		FeishuEmail:            u.FeishuEmail,
		FeishuName:             u.FeishuName,
		FeishuBound:            u.FeishuBound,
		Role:                   u.Role,
		WechatNickname:         u.WechatNickname,
		WechatBound:            u.WechatBound,
		IsBot:                  u.IsBot,
		BotAgentKey:            u.BotAgentKey,
	}
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
func VipOrdersRespV1(orders []*vipv1.VipOrder, total int32) *vipv1.GetVipOrdersResp {
	return &vipv1.GetVipOrdersResp{Orders: orders, Total: total}
}

// NotificationsRespV1 通知列表响应。
func NotificationsRespV1(items []*userv1.Notification, total int32) *userv1.GetNotificationsResp {
	return &userv1.GetNotificationsResp{Notifications: items, Total: total}
}

// NotificationsFromNotifyV1 copies notify.v1 notifications into user.v1 shape.
func NotificationsFromNotifyV1(items []*notifyv1.Notification) []*userv1.Notification {
	if len(items) == 0 {
		return nil
	}
	out := make([]*userv1.Notification, len(items))
	for i, n := range items {
		if n == nil {
			continue
		}
		out[i] = &userv1.Notification{
			Id: n.GetId(), UserId: n.GetUserId(), SenderId: n.GetSenderId(),
			SenderName: n.GetSenderName(), SenderAvatar: n.GetSenderAvatar(),
			Type: n.GetType(), PostId: n.GetPostId(), Content: n.GetContent(),
			IsRead: n.GetIsRead(), CreatedAt: n.GetCreatedAt(),
		}
	}
	return out
}

// FollowingsRespV1 关注列表响应。
func FollowingsRespV1(users []*userv1.User, total int32) *userv1.GetFollowingsResp {
	return &userv1.GetFollowingsResp{Users: users, Total: total}
}

// FollowingsRespFromList 关注列表结果 → v1 响应。
func FollowingsRespFromList(result FollowListResult) *userv1.GetFollowingsResp {
	users := make([]*userv1.User, 0, len(result.Users))
	for i := range result.Users {
		u := result.Users[i]
		users = append(users, ModelToUserV1(&u))
	}
	return &userv1.GetFollowingsResp{Users: users, Total: int32(result.Total)}
}

// SendFriendRequestRespV1 好友申请响应。
func SendFriendRequestRespV1(view *userv1.FriendRequestView) *userv1.SendFriendRequestResp {
	return &userv1.SendFriendRequestResp{Data: view}
}

// ListIncomingFriendRequestsRespV1 收到的好友申请列表。
func ListIncomingFriendRequestsRespV1(data []*userv1.FriendRequestView) *userv1.ListIncomingFriendRequestsResp {
	return &userv1.ListIncomingFriendRequestsResp{Data: data}
}

// ListOutgoingFriendRequestsRespV1 发出的好友申请列表。
func ListOutgoingFriendRequestsRespV1(data []*userv1.FriendRequestView) *userv1.ListOutgoingFriendRequestsResp {
	return &userv1.ListOutgoingFriendRequestsResp{Data: data}
}

// ListFriendsRespV1 好友列表响应。
func ListFriendsRespV1(users []*userv1.User) *userv1.ListFriendsResp {
	return &userv1.ListFriendsResp{Users: users}
}

// GetFriendRelationRespV1 好友关系响应。
func GetFriendRelationRespV1(relation string) *userv1.GetFriendRelationResp {
	return &userv1.GetFriendRelationResp{Relation: relation}
}

// FollowersRespV1 粉丝列表响应。
func FollowersRespV1(result FollowListResult) *userv1.GetFollowersResp {
	users := make([]*userv1.User, 0, len(result.Users))
	for i := range result.Users {
		u := result.Users[i]
		users = append(users, ModelToUserV1(&u))
	}
	return &userv1.GetFollowersResp{Users: users, Total: int32(result.Total)}
}
