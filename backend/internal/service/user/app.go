// Package userapp User 域应用服务（FS-3 Hybrid）。

package userapp

import (
	"context"

	"strconv"

	userbiz "backend/internal/biz/user"

	notifybiz "backend/internal/biz/notify"

	notifydata "backend/internal/data/notify"
	userdata "backend/internal/data/user"

	"backend/model"

	userv1 "backend/api/user/v1"
	vipv1 "backend/api/vip/v1"

	"gorm.io/gorm"
)

// AppService User 应用服务。

type AppService struct {
	db *gorm.DB

	store userbiz.UserStore

	notify notifybiz.NotifyStore
}

// New 构造 AppService。

func New(db *gorm.DB) *AppService {

	return &AppService{

		db: db,

		store: userdata.NewUserStore(db),

		notify: notifydata.NewStore(db),
	}

}

// Login 登录。

func (s *AppService) Login(ctx context.Context, in *userv1.LoginReq) (*userv1.LoginResp, error) {

	user, token, err := userbiz.Login(ctx, s.store, in.GetEmail(), in.GetUsername(), in.GetPassword())

	if err != nil {

		return nil, err

	}

	return userbiz.LoginRespV1(user, token), nil

}

// Register 注册。

func (s *AppService) Register(ctx context.Context, in *userv1.RegisterReq) (*userv1.RegisterResp, error) {

	user, token, err := userbiz.Register(ctx, s.store, in.GetUsername(), in.GetEmail(), in.GetPassword())

	if err != nil {

		return nil, err

	}

	return userbiz.RegisterRespV1(user, token), nil

}

func parseUserID(raw string) (uint, error) {

	n, err := strconv.ParseUint(raw, 10, 64)

	if err != nil || n == 0 {

		return 0, userbiz.ErrInvalidArgument

	}

	return uint(n), nil

}

// GetUserInfo 按 ID 查询。

func (s *AppService) GetUserInfo(ctx context.Context, in *userv1.GetUserInfoReq) (*userv1.GetUserInfoResp, error) {

	uid, err := parseUserID(in.GetUserId())

	if err != nil {

		return nil, err

	}

	user, err := userbiz.GetByID(ctx, s.store, uid)

	if err != nil {

		return nil, err

	}

	return userbiz.UserInfoRespV1(user), nil

}

// GetUser 同 GetUserInfo（super 契约）。

func (s *AppService) GetUser(ctx context.Context, in *userv1.GetUserReq) (*userv1.GetUserResp, error) {

	uid, err := parseUserID(in.GetUserId())

	if err != nil {

		return nil, err

	}

	user, err := userbiz.GetByID(ctx, s.store, uid)

	if err != nil {

		return nil, err

	}

	return userbiz.GetUserRespV1(user), nil

}

// GetUserVipStatus VIP 状态。

func (s *AppService) GetUserVipStatus(ctx context.Context, in *vipv1.GetUserVipStatusReq) (*vipv1.GetUserVipStatusResp, error) {

	uid, err := parseUserID(in.GetUserId())

	if err != nil {

		return nil, err

	}

	st, err := userbiz.GetVipStatus(ctx, s.store, uid)

	if err != nil {

		return nil, err

	}

	return userbiz.GetUserVipStatusRespV1(st), nil

}

// CheckUserVip 是否有效 VIP。

func (s *AppService) CheckUserVip(ctx context.Context, in *vipv1.CheckUserVipReq) (*vipv1.CheckUserVipResp, error) {

	uid, err := parseUserID(in.GetUserId())

	if err != nil {

		return nil, err

	}

	active, err := userbiz.CheckVipActive(ctx, s.store, uid)

	if err != nil {

		return nil, err

	}

	return &vipv1.CheckUserVipResp{IsVip: active}, nil

}

// GetVipOrders VIP 订单列表。

func (s *AppService) GetVipOrders(ctx context.Context, in *vipv1.GetVipOrdersReq) (*vipv1.GetVipOrdersResp, error) {

	orders, total, err := userbiz.ListVipOrders(ctx, s.store, in.GetUserId(), userbiz.VipOrdersPage{

		Page: in.GetPage(),

		PageSize: in.GetPageSize(),
	})

	if err != nil {

		return nil, err

	}

	return userbiz.VipOrdersRespV1(orders, total), nil

}

// GetNotifications 通知列表。

func (s *AppService) GetNotifications(ctx context.Context, in *userv1.GetNotificationsReq) (*userv1.GetNotificationsResp, error) {

	items, total, err := notifybiz.ListInbox(ctx, s.notify, in.GetUserId(), notifybiz.InboxPage{

		Page: in.GetPage(),

		PageSize: in.GetPageSize(),
	})

	if err != nil {

		return nil, err

	}

	return userbiz.NotificationsRespV1(items, total), nil

}

// GetUnreadCount 未读数。

func (s *AppService) GetUnreadCount(ctx context.Context, in *userv1.GetUnreadCountReq) (*userv1.GetUnreadCountResp, error) {

	count, err := notifybiz.UnreadCount(ctx, s.notify, in.GetUserId())

	if err != nil {

		return nil, err

	}

	return &userv1.GetUnreadCountResp{Count: count}, nil

}

// ReadNotification 标记已读。

func (s *AppService) ReadNotification(ctx context.Context, in *userv1.ReadNotificationReq) (*userv1.ReadNotificationResp, error) {

	if err := notifybiz.MarkRead(ctx, s.notify, in.GetUserId(), in.GetId()); err != nil {

		return nil, err

	}

	return &userv1.ReadNotificationResp{}, nil

}

// ReadAllNotifications 全部已读。

func (s *AppService) ReadAllNotifications(ctx context.Context, in *userv1.ReadAllNotificationsReq) (*userv1.ReadAllNotificationsResp, error) {

	if err := notifybiz.MarkAllRead(ctx, s.notify, in.GetUserId()); err != nil {

		return nil, err

	}

	return &userv1.ReadAllNotificationsResp{}, nil

}

// GetUserAvatar 获取用户虚拟形象。

func (s *AppService) GetUserAvatar(ctx context.Context, in *userv1.GetUserAvatarReq) (*userv1.GetUserAvatarResp, error) {
	out, err := userbiz.GetUserAvatar(ctx, s.store, userv1.GetUserAvatarReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.GetUserAvatarRespFromMoe(out), nil
}

// UpdateUserAvatar 更新用户虚拟形象。

func (s *AppService) UpdateUserAvatar(ctx context.Context, in *userv1.UpdateUserAvatarReq) (*userv1.UpdateUserAvatarResp, error) {
	out, err := userbiz.UpdateUserAvatar(ctx, s.store, userv1.UpdateUserAvatarReqToMoe(in))
	if err != nil {
		return nil, err
	}
	return userv1.UpdateUserAvatarRespFromMoe(out), nil
}

// DB 暴露给渐进迁移（仅 Hybrid 内部）。

func (s *AppService) DB() *gorm.DB {

	return s.db

}

// Store 暴露 UserStore（Hybrid 内部）。

func (s *AppService) Store() userbiz.UserStore {

	return s.store

}

// Notify 暴露 NotifyStore（Hybrid GW 内部）。

func (s *AppService) Notify() notifybiz.NotifyStore {

	return s.notify

}

// EnsureUser 加载用户（供扩展）。

func (s *AppService) EnsureUser(ctx context.Context, userID uint) (model.User, error) {

	return userbiz.GetByID(ctx, s.store, userID)

}

// Follow 关注用户。

func (s *AppService) Follow(ctx context.Context, in *userv1.FollowUserReq) (*userv1.FollowUserResp, error) {

	followerID, followingID, err := userbiz.ParseFollowPair(in.GetUserId(), in.GetFollowingId())

	if err != nil {

		return nil, err

	}

	if err := userbiz.Follow(ctx, s.store, followerID, followingID); err != nil {

		return nil, err

	}

	return &userv1.FollowUserResp{Success: true}, nil

}

// Unfollow 取消关注。

func (s *AppService) Unfollow(ctx context.Context, in *userv1.UnfollowUserReq) (*userv1.FollowUserResp, error) {

	followerID, followingID, err := userbiz.ParseFollowPair(in.GetUserId(), in.GetFollowingId())

	if err != nil {

		return nil, err

	}

	if err := userbiz.Unfollow(ctx, s.store, followerID, followingID); err != nil {

		return nil, err

	}

	return &userv1.FollowUserResp{Success: true}, nil

}

// CheckFollow 是否关注。

func (s *AppService) CheckFollow(ctx context.Context, in *userv1.CheckFollowReq) (*userv1.CheckFollowResp, error) {

	ok, err := userbiz.IsFollowingByStringID(ctx, s.store, in.GetFollowerId(), in.GetFollowingId())

	if err != nil {

		return nil, err

	}

	return &userv1.CheckFollowResp{IsFollowing: ok}, nil

}

// GetFollowers 粉丝列表。

func (s *AppService) GetFollowers(ctx context.Context, in *userv1.GetFollowersReq) (*userv1.GetFollowersResp, error) {

	uid, err := parseUserID(in.GetUserId())

	if err != nil {

		return nil, err

	}

	result, err := userbiz.ListFollowers(ctx, s.store, uid, userbiz.FollowListPage{

		Page: in.GetPage(),

		PageSize: in.GetPageSize(),
	})

	if err != nil {

		return nil, err

	}

	return followListToProto(result), nil

}

// GetFollowings 关注列表。

func (s *AppService) GetFollowings(ctx context.Context, in *userv1.GetFollowingsReq) (*userv1.GetFollowingsResp, error) {

	uid, err := parseUserID(in.GetUserId())

	if err != nil {

		return nil, err

	}

	result, err := userbiz.ListFollowings(ctx, s.store, uid, userbiz.FollowListPage{

		Page: in.GetPage(),

		PageSize: in.GetPageSize(),
	})

	if err != nil {

		return nil, err

	}

	resp := followListToProto(result)
	m := userv1.GetFollowersRespToMoe(resp)
	return userbiz.FollowingsRespV1(m.Users, m.Total), nil

}

// SendFriendRequest 发起好友申请。

func (s *AppService) SendFriendRequest(ctx context.Context, in *userv1.SendFriendRequestReq) (*userv1.SendFriendRequestResp, error) {

	me, err := userbiz.ParseActorUserID(in.GetActorUserId())

	if err != nil {

		return nil, err

	}

	view, err := userbiz.SendFriendRequest(ctx, s.store, me, in.GetToUserId(), in.GetToMoeNo())

	if err != nil {

		return nil, err

	}

	return userbiz.SendFriendRequestRespV1(view), nil

}

// ListIncomingFriendRequests 收到的申请。

func (s *AppService) ListIncomingFriendRequests(ctx context.Context, in *userv1.ListIncomingFriendRequestsReq) (*userv1.ListIncomingFriendRequestsResp, error) {

	me, err := userbiz.ParseActorUserID(in.GetActorUserId())

	if err != nil {

		return nil, err

	}

	data, err := userbiz.ListIncomingFriendRequests(ctx, s.store, me)

	if err != nil {

		return nil, err

	}

	return userbiz.ListIncomingFriendRequestsRespV1(data), nil

}

// ListOutgoingFriendRequests 发出的申请。

func (s *AppService) ListOutgoingFriendRequests(ctx context.Context, in *userv1.ListOutgoingFriendRequestsReq) (*userv1.ListOutgoingFriendRequestsResp, error) {

	me, err := userbiz.ParseActorUserID(in.GetActorUserId())

	if err != nil {

		return nil, err

	}

	data, err := userbiz.ListOutgoingFriendRequests(ctx, s.store, me)

	if err != nil {

		return nil, err

	}

	return userbiz.ListOutgoingFriendRequestsRespV1(data), nil

}

// AcceptFriendRequest 同意申请。

func (s *AppService) AcceptFriendRequest(ctx context.Context, in *userv1.AcceptFriendRequestReq) (*userv1.AcceptFriendRequestResp, error) {

	me, err := userbiz.ParseActorUserID(in.GetActorUserId())

	if err != nil {

		return nil, err

	}

	if err := userbiz.AcceptFriendRequest(ctx, s.store, me, in.GetRequestId()); err != nil {

		return nil, err

	}

	return &userv1.AcceptFriendRequestResp{Ok: true}, nil

}

// RejectFriendRequest 拒绝申请。

func (s *AppService) RejectFriendRequest(ctx context.Context, in *userv1.RejectFriendRequestReq) (*userv1.RejectFriendRequestResp, error) {

	me, err := userbiz.ParseActorUserID(in.GetActorUserId())

	if err != nil {

		return nil, err

	}

	if err := userbiz.RejectFriendRequest(ctx, s.store, me, in.GetRequestId()); err != nil {

		return nil, err

	}

	return &userv1.RejectFriendRequestResp{Ok: true}, nil

}

// ListFriends 好友列表。

func (s *AppService) ListFriends(ctx context.Context, in *userv1.ListFriendsReq) (*userv1.ListFriendsResp, error) {

	me, err := userbiz.ParseActorUserID(in.GetActorUserId())

	if err != nil {

		return nil, err

	}

	users, err := userbiz.ListFriends(ctx, s.store, me)

	if err != nil {

		return nil, err

	}

	return userbiz.ListFriendsRespV1(users), nil

}

// GetFriendRelation 好友关系状态。

func (s *AppService) GetFriendRelation(ctx context.Context, in *userv1.GetFriendRelationReq) (*userv1.GetFriendRelationResp, error) {

	me, err := userbiz.ParseActorUserID(in.GetActorUserId())

	if err != nil {

		return nil, err

	}

	other, err := parseUserID(in.GetOtherUserId())

	if err != nil {

		return nil, err

	}

	rel, err := userbiz.GetFriendRelation(ctx, s.store, me, other)

	if err != nil {

		return nil, err

	}

	return userbiz.GetFriendRelationRespV1(rel), nil

}

func followListToProto(result userbiz.FollowListResult) *userv1.GetFollowersResp {
	return userbiz.FollowersRespV1(result)
}
