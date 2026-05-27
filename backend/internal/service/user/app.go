// Package userapp User 域应用服务（FS-3 Hybrid）。
package userapp

import (
	"context"
	"strconv"

	userbiz "backend/internal/biz/user"
	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// AppService User 应用服务。
type AppService struct {
	db *gorm.DB
}

// New 构造 AppService。
func New(db *gorm.DB) *AppService {
	return &AppService{db: db}
}

// Login 登录。
func (s *AppService) Login(ctx context.Context, in *super.LoginReq) (*super.LoginResp, error) {
	user, token, err := userbiz.Login(ctx, s.db, in.GetEmail(), in.GetUsername(), in.GetPassword())
	if err != nil {
		return nil, err
	}
	return &super.LoginResp{
		User:  userbiz.ModelToProto(&user),
		Token: token,
	}, nil
}

// Register 注册。
func (s *AppService) Register(ctx context.Context, in *super.RegisterReq) (*super.RegisterResp, error) {
	user, token, err := userbiz.Register(ctx, s.db, in.GetUsername(), in.GetEmail(), in.GetPassword())
	if err != nil {
		return nil, err
	}
	return &super.RegisterResp{
		User:  userbiz.ModelToProto(&user),
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
func (s *AppService) GetUserInfo(ctx context.Context, in *super.GetUserInfoReq) (*super.GetUserInfoResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	user, err := userbiz.GetByID(ctx, s.db, uid)
	if err != nil {
		return nil, err
	}
	return &super.GetUserInfoResp{User: userbiz.ModelToProto(&user)}, nil
}

// GetUser 同 GetUserInfo（super 契约）。
func (s *AppService) GetUser(ctx context.Context, in *super.GetUserReq) (*super.GetUserResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	user, err := userbiz.GetByID(ctx, s.db, uid)
	if err != nil {
		return nil, err
	}
	return &super.GetUserResp{User: userbiz.ModelToProto(&user)}, nil
}

// GetUserVipStatus VIP 状态。
func (s *AppService) GetUserVipStatus(ctx context.Context, in *super.GetUserVipStatusReq) (*super.GetUserVipStatusResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	st, err := userbiz.GetVipStatus(ctx, s.db, uid)
	if err != nil {
		return nil, err
	}
	return &super.GetUserVipStatusResp{
		IsVip:     st.IsVip,
		ExpiresAt: st.ExpiresAt,
		AutoRenew: st.AutoRenew,
	}, nil
}

// CheckUserVip 是否有效 VIP。
func (s *AppService) CheckUserVip(ctx context.Context, in *super.CheckUserVipReq) (*super.CheckUserVipResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	active, err := userbiz.CheckVipActive(ctx, s.db, uid)
	if err != nil {
		return nil, err
	}
	return &super.CheckUserVipResp{IsVip: active}, nil
}

// DB 暴露给渐进迁移（仅 Hybrid 内部）。
func (s *AppService) DB() *gorm.DB {
	return s.db
}

// EnsureUser 加载用户（供扩展）。
func (s *AppService) EnsureUser(ctx context.Context, userID uint) (model.User, error) {
	return userbiz.GetByID(ctx, s.db, userID)
}

// Follow 关注用户。
func (s *AppService) Follow(ctx context.Context, in *super.FollowUserReq) (*super.FollowUserResp, error) {
	followerID, followingID, err := userbiz.ParseFollowPair(in.GetUserId(), in.GetFollowingId())
	if err != nil {
		return nil, err
	}
	if err := userbiz.Follow(ctx, s.db, followerID, followingID); err != nil {
		return nil, err
	}
	return &super.FollowUserResp{Success: true}, nil
}

// Unfollow 取消关注。
func (s *AppService) Unfollow(ctx context.Context, in *super.UnfollowUserReq) (*super.FollowUserResp, error) {
	followerID, followingID, err := userbiz.ParseFollowPair(in.GetUserId(), in.GetFollowingId())
	if err != nil {
		return nil, err
	}
	if err := userbiz.Unfollow(ctx, s.db, followerID, followingID); err != nil {
		return nil, err
	}
	return &super.FollowUserResp{Success: true}, nil
}

// CheckFollow 是否关注。
func (s *AppService) CheckFollow(ctx context.Context, in *super.CheckFollowReq) (*super.CheckFollowResp, error) {
	ok, err := userbiz.IsFollowingByStringID(ctx, s.db, in.GetFollowerId(), in.GetFollowingId())
	if err != nil {
		return nil, err
	}
	return &super.CheckFollowResp{IsFollowing: ok}, nil
}

// GetFollowers 粉丝列表。
func (s *AppService) GetFollowers(ctx context.Context, in *super.GetFollowersReq) (*super.GetFollowersResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	result, err := userbiz.ListFollowers(ctx, s.db, uid, userbiz.FollowListPage{
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
	})
	if err != nil {
		return nil, err
	}
	return followListToProto(result), nil
}

// GetFollowings 关注列表。
func (s *AppService) GetFollowings(ctx context.Context, in *super.GetFollowingsReq) (*super.GetFollowingsResp, error) {
	uid, err := parseUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	result, err := userbiz.ListFollowings(ctx, s.db, uid, userbiz.FollowListPage{
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
	})
	if err != nil {
		return nil, err
	}
	resp := followListToProto(result)
	return &super.GetFollowingsResp{Users: resp.Users, Total: resp.Total}, nil
}

// SendFriendRequest 发起好友申请。
func (s *AppService) SendFriendRequest(ctx context.Context, in *super.SendFriendRequestReq) (*super.SendFriendRequestResp, error) {
	me, err := userbiz.ParseActorUserID(in.GetActorUserId())
	if err != nil {
		return nil, err
	}
	view, err := userbiz.SendFriendRequest(ctx, s.db, me, in.GetToUserId(), in.GetToMoeNo())
	if err != nil {
		return nil, err
	}
	return &super.SendFriendRequestResp{Data: view}, nil
}

// ListIncomingFriendRequests 收到的申请。
func (s *AppService) ListIncomingFriendRequests(ctx context.Context, in *super.ListIncomingFriendRequestsReq) (*super.ListIncomingFriendRequestsResp, error) {
	me, err := userbiz.ParseActorUserID(in.GetActorUserId())
	if err != nil {
		return nil, err
	}
	data, err := userbiz.ListIncomingFriendRequests(ctx, s.db, me)
	if err != nil {
		return nil, err
	}
	return &super.ListIncomingFriendRequestsResp{Data: data}, nil
}

// ListOutgoingFriendRequests 发出的申请。
func (s *AppService) ListOutgoingFriendRequests(ctx context.Context, in *super.ListOutgoingFriendRequestsReq) (*super.ListOutgoingFriendRequestsResp, error) {
	me, err := userbiz.ParseActorUserID(in.GetActorUserId())
	if err != nil {
		return nil, err
	}
	data, err := userbiz.ListOutgoingFriendRequests(ctx, s.db, me)
	if err != nil {
		return nil, err
	}
	return &super.ListOutgoingFriendRequestsResp{Data: data}, nil
}

// AcceptFriendRequest 同意申请。
func (s *AppService) AcceptFriendRequest(ctx context.Context, in *super.AcceptFriendRequestReq) (*super.AcceptFriendRequestResp, error) {
	me, err := userbiz.ParseActorUserID(in.GetActorUserId())
	if err != nil {
		return nil, err
	}
	if err := userbiz.AcceptFriendRequest(ctx, s.db, me, in.GetRequestId()); err != nil {
		return nil, err
	}
	return &super.AcceptFriendRequestResp{Ok: true}, nil
}

// RejectFriendRequest 拒绝申请。
func (s *AppService) RejectFriendRequest(ctx context.Context, in *super.RejectFriendRequestReq) (*super.RejectFriendRequestResp, error) {
	me, err := userbiz.ParseActorUserID(in.GetActorUserId())
	if err != nil {
		return nil, err
	}
	if err := userbiz.RejectFriendRequest(ctx, s.db, me, in.GetRequestId()); err != nil {
		return nil, err
	}
	return &super.RejectFriendRequestResp{Ok: true}, nil
}

// ListFriends 好友列表。
func (s *AppService) ListFriends(ctx context.Context, in *super.ListFriendsReq) (*super.ListFriendsResp, error) {
	me, err := userbiz.ParseActorUserID(in.GetActorUserId())
	if err != nil {
		return nil, err
	}
	users, err := userbiz.ListFriends(ctx, s.db, me)
	if err != nil {
		return nil, err
	}
	return &super.ListFriendsResp{Users: users}, nil
}

// GetFriendRelation 好友关系状态。
func (s *AppService) GetFriendRelation(ctx context.Context, in *super.GetFriendRelationReq) (*super.GetFriendRelationResp, error) {
	me, err := userbiz.ParseActorUserID(in.GetActorUserId())
	if err != nil {
		return nil, err
	}
	other, err := parseUserID(in.GetOtherUserId())
	if err != nil {
		return nil, err
	}
	rel, err := userbiz.GetFriendRelation(ctx, s.db, me, other)
	if err != nil {
		return nil, err
	}
	return &super.GetFriendRelationResp{Relation: rel}, nil
}

func followListToProto(result userbiz.FollowListResult) *super.GetFollowersResp {
	users := make([]*super.User, 0, len(result.Users))
	for i := range result.Users {
		u := result.Users[i]
		users = append(users, userbiz.ModelToProto(&u))
	}
	return &super.GetFollowersResp{
		Users: users,
		Total: int32(result.Total),
	}
}
