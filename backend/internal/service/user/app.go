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

	"backend/rpc/pb/moe"

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

func (s *AppService) Login(ctx context.Context, in *moe.LoginReq) (*moe.LoginResp, error) {

	user, token, err := userbiz.Login(ctx, s.store, in.GetEmail(), in.GetUsername(), in.GetPassword())

	if err != nil {

		return nil, err

	}

	return &moe.LoginResp{

		User: userbiz.ModelToProto(&user),

		Token: token,
	}, nil

}

// Register 注册。

func (s *AppService) Register(ctx context.Context, in *moe.RegisterReq) (*moe.RegisterResp, error) {

	user, token, err := userbiz.Register(ctx, s.store, in.GetUsername(), in.GetEmail(), in.GetPassword())

	if err != nil {

		return nil, err

	}

	return &moe.RegisterResp{

		User: userbiz.ModelToProto(&user),

		Token: token,
	}, nil

}

func parseUserID(raw string) (uint, error) {

	n, err := strconv.ParseUint(raw, 10, 64)

	if err != nil || n == 0 {

		return 0, userbiz.ErrInvalidArgument

	}

	return uint(n), nil

}

// GetUserInfo 按 ID 查询。

func (s *AppService) GetUserInfo(ctx context.Context, in *moe.GetUserInfoReq) (*moe.GetUserInfoResp, error) {

	uid, err := parseUserID(in.GetUserId())

	if err != nil {

		return nil, err

	}

	user, err := userbiz.GetByID(ctx, s.store, uid)

	if err != nil {

		return nil, err

	}

	return &moe.GetUserInfoResp{User: userbiz.ModelToProto(&user)}, nil

}

// GetUser 同 GetUserInfo（super 契约）。

func (s *AppService) GetUser(ctx context.Context, in *moe.GetUserReq) (*moe.GetUserResp, error) {

	uid, err := parseUserID(in.GetUserId())

	if err != nil {

		return nil, err

	}

	user, err := userbiz.GetByID(ctx, s.store, uid)

	if err != nil {

		return nil, err

	}

	return &moe.GetUserResp{User: userbiz.ModelToProto(&user)}, nil

}

// GetUserVipStatus VIP 状态。

func (s *AppService) GetUserVipStatus(ctx context.Context, in *moe.GetUserVipStatusReq) (*moe.GetUserVipStatusResp, error) {

	uid, err := parseUserID(in.GetUserId())

	if err != nil {

		return nil, err

	}

	st, err := userbiz.GetVipStatus(ctx, s.store, uid)

	if err != nil {

		return nil, err

	}

	return &moe.GetUserVipStatusResp{

		IsVip: st.IsVip,

		ExpiresAt: st.ExpiresAt,

		AutoRenew: st.AutoRenew,
	}, nil

}

// CheckUserVip 是否有效 VIP。

func (s *AppService) CheckUserVip(ctx context.Context, in *moe.CheckUserVipReq) (*moe.CheckUserVipResp, error) {

	uid, err := parseUserID(in.GetUserId())

	if err != nil {

		return nil, err

	}

	active, err := userbiz.CheckVipActive(ctx, s.store, uid)

	if err != nil {

		return nil, err

	}

	return &moe.CheckUserVipResp{IsVip: active}, nil

}

// GetVipOrders VIP 订单列表。

func (s *AppService) GetVipOrders(ctx context.Context, in *moe.GetVipOrdersReq) (*moe.GetVipOrdersResp, error) {

	orders, total, err := userbiz.ListVipOrders(ctx, s.store, in.GetUserId(), userbiz.VipOrdersPage{

		Page: in.GetPage(),

		PageSize: in.GetPageSize(),
	})

	if err != nil {

		return nil, err

	}

	return &moe.GetVipOrdersResp{Orders: orders, Total: total}, nil

}

// GetNotifications 通知列表。

func (s *AppService) GetNotifications(ctx context.Context, in *moe.GetNotificationsReq) (*moe.GetNotificationsResp, error) {

	items, total, err := notifybiz.ListInbox(ctx, s.notify, in.GetUserId(), notifybiz.InboxPage{

		Page: in.GetPage(),

		PageSize: in.GetPageSize(),
	})

	if err != nil {

		return nil, err

	}

	return &moe.GetNotificationsResp{Notifications: items, Total: total}, nil

}

// GetUnreadCount 未读数。

func (s *AppService) GetUnreadCount(ctx context.Context, in *moe.GetUnreadCountReq) (*moe.GetUnreadCountResp, error) {

	count, err := notifybiz.UnreadCount(ctx, s.notify, in.GetUserId())

	if err != nil {

		return nil, err

	}

	return &moe.GetUnreadCountResp{Count: count}, nil

}

// ReadNotification 标记已读。

func (s *AppService) ReadNotification(ctx context.Context, in *moe.ReadNotificationReq) (*moe.ReadNotificationResp, error) {

	if err := notifybiz.MarkRead(ctx, s.notify, in.GetUserId(), in.GetId()); err != nil {

		return nil, err

	}

	return &moe.ReadNotificationResp{}, nil

}

// ReadAllNotifications 全部已读。

func (s *AppService) ReadAllNotifications(ctx context.Context, in *moe.ReadAllNotificationsReq) (*moe.ReadAllNotificationsResp, error) {

	if err := notifybiz.MarkAllRead(ctx, s.notify, in.GetUserId()); err != nil {

		return nil, err

	}

	return &moe.ReadAllNotificationsResp{}, nil

}

// GetUserAvatar 获取用户虚拟形象。

func (s *AppService) GetUserAvatar(ctx context.Context, in *moe.GetUserAvatarReq) (*moe.GetUserAvatarResp, error) {

	return userbiz.GetUserAvatar(ctx, s.store, in)

}

// UpdateUserAvatar 更新用户虚拟形象。

func (s *AppService) UpdateUserAvatar(ctx context.Context, in *moe.UpdateUserAvatarReq) (*moe.UpdateUserAvatarResp, error) {

	return userbiz.UpdateUserAvatar(ctx, s.store, in)

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

func (s *AppService) Follow(ctx context.Context, in *moe.FollowUserReq) (*moe.FollowUserResp, error) {

	followerID, followingID, err := userbiz.ParseFollowPair(in.GetUserId(), in.GetFollowingId())

	if err != nil {

		return nil, err

	}

	if err := userbiz.Follow(ctx, s.store, followerID, followingID); err != nil {

		return nil, err

	}

	return &moe.FollowUserResp{Success: true}, nil

}

// Unfollow 取消关注。

func (s *AppService) Unfollow(ctx context.Context, in *moe.UnfollowUserReq) (*moe.FollowUserResp, error) {

	followerID, followingID, err := userbiz.ParseFollowPair(in.GetUserId(), in.GetFollowingId())

	if err != nil {

		return nil, err

	}

	if err := userbiz.Unfollow(ctx, s.store, followerID, followingID); err != nil {

		return nil, err

	}

	return &moe.FollowUserResp{Success: true}, nil

}

// CheckFollow 是否关注。

func (s *AppService) CheckFollow(ctx context.Context, in *moe.CheckFollowReq) (*moe.CheckFollowResp, error) {

	ok, err := userbiz.IsFollowingByStringID(ctx, s.store, in.GetFollowerId(), in.GetFollowingId())

	if err != nil {

		return nil, err

	}

	return &moe.CheckFollowResp{IsFollowing: ok}, nil

}

// GetFollowers 粉丝列表。

func (s *AppService) GetFollowers(ctx context.Context, in *moe.GetFollowersReq) (*moe.GetFollowersResp, error) {

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

func (s *AppService) GetFollowings(ctx context.Context, in *moe.GetFollowingsReq) (*moe.GetFollowingsResp, error) {

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

	return &moe.GetFollowingsResp{Users: resp.Users, Total: resp.Total}, nil

}

// SendFriendRequest 发起好友申请。

func (s *AppService) SendFriendRequest(ctx context.Context, in *moe.SendFriendRequestReq) (*moe.SendFriendRequestResp, error) {

	me, err := userbiz.ParseActorUserID(in.GetActorUserId())

	if err != nil {

		return nil, err

	}

	view, err := userbiz.SendFriendRequest(ctx, s.store, me, in.GetToUserId(), in.GetToMoeNo())

	if err != nil {

		return nil, err

	}

	return &moe.SendFriendRequestResp{Data: view}, nil

}

// ListIncomingFriendRequests 收到的申请。

func (s *AppService) ListIncomingFriendRequests(ctx context.Context, in *moe.ListIncomingFriendRequestsReq) (*moe.ListIncomingFriendRequestsResp, error) {

	me, err := userbiz.ParseActorUserID(in.GetActorUserId())

	if err != nil {

		return nil, err

	}

	data, err := userbiz.ListIncomingFriendRequests(ctx, s.store, me)

	if err != nil {

		return nil, err

	}

	return &moe.ListIncomingFriendRequestsResp{Data: data}, nil

}

// ListOutgoingFriendRequests 发出的申请。

func (s *AppService) ListOutgoingFriendRequests(ctx context.Context, in *moe.ListOutgoingFriendRequestsReq) (*moe.ListOutgoingFriendRequestsResp, error) {

	me, err := userbiz.ParseActorUserID(in.GetActorUserId())

	if err != nil {

		return nil, err

	}

	data, err := userbiz.ListOutgoingFriendRequests(ctx, s.store, me)

	if err != nil {

		return nil, err

	}

	return &moe.ListOutgoingFriendRequestsResp{Data: data}, nil

}

// AcceptFriendRequest 同意申请。

func (s *AppService) AcceptFriendRequest(ctx context.Context, in *moe.AcceptFriendRequestReq) (*moe.AcceptFriendRequestResp, error) {

	me, err := userbiz.ParseActorUserID(in.GetActorUserId())

	if err != nil {

		return nil, err

	}

	if err := userbiz.AcceptFriendRequest(ctx, s.store, me, in.GetRequestId()); err != nil {

		return nil, err

	}

	return &moe.AcceptFriendRequestResp{Ok: true}, nil

}

// RejectFriendRequest 拒绝申请。

func (s *AppService) RejectFriendRequest(ctx context.Context, in *moe.RejectFriendRequestReq) (*moe.RejectFriendRequestResp, error) {

	me, err := userbiz.ParseActorUserID(in.GetActorUserId())

	if err != nil {

		return nil, err

	}

	if err := userbiz.RejectFriendRequest(ctx, s.store, me, in.GetRequestId()); err != nil {

		return nil, err

	}

	return &moe.RejectFriendRequestResp{Ok: true}, nil

}

// ListFriends 好友列表。

func (s *AppService) ListFriends(ctx context.Context, in *moe.ListFriendsReq) (*moe.ListFriendsResp, error) {

	me, err := userbiz.ParseActorUserID(in.GetActorUserId())

	if err != nil {

		return nil, err

	}

	users, err := userbiz.ListFriends(ctx, s.store, me)

	if err != nil {

		return nil, err

	}

	return &moe.ListFriendsResp{Users: users}, nil

}

// GetFriendRelation 好友关系状态。

func (s *AppService) GetFriendRelation(ctx context.Context, in *moe.GetFriendRelationReq) (*moe.GetFriendRelationResp, error) {

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

	return &moe.GetFriendRelationResp{Relation: rel}, nil

}

func followListToProto(result userbiz.FollowListResult) *moe.GetFollowersResp {

	users := make([]*moe.User, 0, len(result.Users))

	for i := range result.Users {

		u := result.Users[i]

		users = append(users, userbiz.ModelToProto(&u))

	}

	return &moe.GetFollowersResp{

		Users: users,

		Total: int32(result.Total),
	}

}
