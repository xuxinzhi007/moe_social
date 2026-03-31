package logic

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type FriendRelationLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewFriendRelationLogic(ctx context.Context, svcCtx *svc.ServiceContext) *FriendRelationLogic {
	return &FriendRelationLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func parseActorUint(s string) (uint, error) {
	v, err := strconv.ParseUint(strings.TrimSpace(s), 10, 64)
	if err != nil {
		return 0, err
	}
	return uint(v), nil
}

func friendRequestViewProto(db *gorm.DB, fr model.FriendRequest) *super.FriendRequestView {
	_, _ = utils.EnsureUserMoeNo(db, fr.FromUserID)
	_, _ = utils.EnsureUserMoeNo(db, fr.ToUserID)
	var fromU, toU model.User
	_ = db.First(&fromU, fr.FromUserID).Error
	_ = db.First(&toU, fr.ToUserID).Error
	return &super.FriendRequestView{
		Id:        strconv.Itoa(int(fr.ID)),
		FromUser:  modelUserToProto(&fromU),
		ToUser:    modelUserToProto(&toU),
		Status:    fr.Status,
		CreatedAt: fr.CreatedAt.Format(time.RFC3339),
	}
}

func ensureMutualFollow(db *gorm.DB, a, b uint) {
	var n int64
	db.Model(&model.Follow{}).Where("follower_id = ? AND following_id = ?", a, b).Count(&n)
	if n == 0 {
		_ = db.Create(&model.Follow{FollowerID: a, FollowingID: b}).Error
	}
	db.Model(&model.Follow{}).Where("follower_id = ? AND following_id = ?", b, a).Count(&n)
	if n == 0 {
		_ = db.Create(&model.Follow{FollowerID: b, FollowingID: a}).Error
	}
}

func (l *FriendRelationLogic) SendFriendRequest(in *super.SendFriendRequestReq) (*super.SendFriendRequestResp, error) {
	me, err := parseActorUint(in.GetActorUserId())
	if err != nil || me == 0 {
		return nil, errorx.Unauthenticated("请先登录")
	}

	db := l.svcCtx.DB
	toID := uint(0)
	if tid := strings.TrimSpace(in.GetToUserId()); tid != "" {
		toID, err = parseActorUint(tid)
		if err != nil {
			return nil, errorx.InvalidArgument("无效的用户 ID")
		}
	} else if moe := strings.TrimSpace(in.GetToMoeNo()); moe != "" {
		var u model.User
		if err := db.Where("moe_no = ?", moe).First(&u).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return nil, errorx.NotFound("未找到该 Moe 号")
			}
			return nil, errorx.Internal("查询失败")
		}
		toID = u.ID
	} else {
		return nil, errorx.InvalidArgument("请填写 to_user_id 或 to_moe_no")
	}

	if toID == me {
		return nil, errorx.InvalidArgument("不能向自己发起申请")
	}

	var target model.User
	if err := db.First(&target, toID).Error; err != nil {
		return nil, errorx.NotFound("用户不存在")
	}

	var fr model.FriendRequest
	err = db.Where("from_user_id = ? AND to_user_id = ?", me, toID).First(&fr).Error
	if err == nil {
		switch fr.Status {
		case "pending":
			return nil, errorx.AlreadyExists("已发送申请，请等待对方处理")
		case "accepted":
			return nil, errorx.AlreadyExists("你们已经是好友")
		case "rejected":
			fr.Status = "pending"
			if err := db.Save(&fr).Error; err != nil {
				return nil, errorx.Internal("保存失败")
			}
			return &super.SendFriendRequestResp{Data: friendRequestViewProto(db, fr)}, nil
		}
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, errorx.Internal("查询失败")
	}

	fr = model.FriendRequest{FromUserID: me, ToUserID: toID, Status: "pending"}
	if err := db.Create(&fr).Error; err != nil {
		return nil, errorx.Internal("创建申请失败")
	}
	_ = db.First(&fr, fr.ID).Error

	return &super.SendFriendRequestResp{Data: friendRequestViewProto(db, fr)}, nil
}

func (l *FriendRelationLogic) ListIncomingFriendRequests(in *super.ListIncomingFriendRequestsReq) (*super.ListIncomingFriendRequestsResp, error) {
	me, err := parseActorUint(in.GetActorUserId())
	if err != nil || me == 0 {
		return nil, errorx.Unauthenticated("请先登录")
	}

	var list []model.FriendRequest
	if err := l.svcCtx.DB.Where("to_user_id = ? AND status = ?", me, "pending").Order("id desc").Find(&list).Error; err != nil {
		return nil, errorx.Internal("加载失败")
	}
	out := make([]*super.FriendRequestView, 0, len(list))
	for _, fr := range list {
		out = append(out, friendRequestViewProto(l.svcCtx.DB, fr))
	}
	return &super.ListIncomingFriendRequestsResp{Data: out}, nil
}

func (l *FriendRelationLogic) ListOutgoingFriendRequests(in *super.ListOutgoingFriendRequestsReq) (*super.ListOutgoingFriendRequestsResp, error) {
	me, err := parseActorUint(in.GetActorUserId())
	if err != nil || me == 0 {
		return nil, errorx.Unauthenticated("请先登录")
	}

	var list []model.FriendRequest
	if err := l.svcCtx.DB.Where("from_user_id = ? AND status = ?", me, "pending").Order("id desc").Find(&list).Error; err != nil {
		return nil, errorx.Internal("加载失败")
	}
	out := make([]*super.FriendRequestView, 0, len(list))
	for _, fr := range list {
		out = append(out, friendRequestViewProto(l.svcCtx.DB, fr))
	}
	return &super.ListOutgoingFriendRequestsResp{Data: out}, nil
}

func loadOwnedPendingRequest(db *gorm.DB, me uint, requestID string) (*model.FriendRequest, error) {
	rid, err := parseActorUint(requestID)
	if err != nil {
		return nil, err
	}
	var fr model.FriendRequest
	if err := db.First(&fr, rid).Error; err != nil {
		return nil, err
	}
	if fr.ToUserID != me || fr.Status != "pending" {
		return nil, errors.New("invalid")
	}
	return &fr, nil
}

func (l *FriendRelationLogic) AcceptFriendRequest(in *super.AcceptFriendRequestReq) (*super.AcceptFriendRequestResp, error) {
	me, err := parseActorUint(in.GetActorUserId())
	if err != nil || me == 0 {
		return nil, errorx.Unauthenticated("请先登录")
	}

	fr, err := loadOwnedPendingRequest(l.svcCtx.DB, me, in.GetRequestId())
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errorx.NotFound("申请不存在")
		}
		return nil, errorx.InvalidArgument("无法处理该申请")
	}

	fr.Status = "accepted"
	if err := l.svcCtx.DB.Save(fr).Error; err != nil {
		return nil, errorx.Internal("保存失败")
	}
	ensureMutualFollow(l.svcCtx.DB, fr.FromUserID, fr.ToUserID)

	return &super.AcceptFriendRequestResp{Ok: true}, nil
}

func (l *FriendRelationLogic) RejectFriendRequest(in *super.RejectFriendRequestReq) (*super.RejectFriendRequestResp, error) {
	me, err := parseActorUint(in.GetActorUserId())
	if err != nil || me == 0 {
		return nil, errorx.Unauthenticated("请先登录")
	}

	fr, err := loadOwnedPendingRequest(l.svcCtx.DB, me, in.GetRequestId())
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errorx.NotFound("申请不存在")
		}
		return nil, errorx.InvalidArgument("无法处理该申请")
	}

	fr.Status = "rejected"
	if err := l.svcCtx.DB.Save(fr).Error; err != nil {
		return nil, errorx.Internal("保存失败")
	}

	return &super.RejectFriendRequestResp{Ok: true}, nil
}

func (l *FriendRelationLogic) ListFriends(in *super.ListFriendsReq) (*super.ListFriendsResp, error) {
	me, err := parseActorUint(in.GetActorUserId())
	if err != nil || me == 0 {
		return nil, errorx.Unauthenticated("请先登录")
	}

	var list []model.FriendRequest
	if err := l.svcCtx.DB.Where("status = ? AND (from_user_id = ? OR to_user_id = ?)", "accepted", me, me).Find(&list).Error; err != nil {
		return nil, errorx.Internal("加载失败")
	}

	seen := make(map[uint]struct{})
	ids := make([]uint, 0)
	for _, fr := range list {
		other := fr.FromUserID
		if other == me {
			other = fr.ToUserID
		}
		if _, ok := seen[other]; ok {
			continue
		}
		seen[other] = struct{}{}
		ids = append(ids, other)
	}

	out := make([]*super.User, 0, len(ids))
	db := l.svcCtx.DB
	for _, id := range ids {
		var u model.User
		if err := db.First(&u, id).Error; err != nil {
			continue
		}
		_, _ = utils.EnsureUserMoeNo(db, u.ID)
		_ = db.First(&u, u.ID).Error
		out = append(out, modelUserToProto(&u))
	}

	return &super.ListFriendsResp{Users: out}, nil
}

func (l *FriendRelationLogic) GetFriendRelation(in *super.GetFriendRelationReq) (*super.GetFriendRelationResp, error) {
	me, err := parseActorUint(in.GetActorUserId())
	if err != nil || me == 0 {
		return nil, errorx.Unauthenticated("请先登录")
	}
	other, err := parseActorUint(in.GetOtherUserId())
	if err != nil {
		return nil, errorx.InvalidArgument("无效用户")
	}

	rel := "none"
	db := l.svcCtx.DB

	var acc model.FriendRequest
	q := db.Where("status = ? AND ((from_user_id = ? AND to_user_id = ?) OR (from_user_id = ? AND to_user_id = ?))",
		"accepted", me, other, other, me).First(&acc)
	if q.Error == nil {
		rel = "friend"
	} else {
		var p model.FriendRequest
		if err := db.Where("from_user_id = ? AND to_user_id = ? AND status = ?", me, other, "pending").First(&p).Error; err == nil {
			rel = "pending_out"
		} else if err := db.Where("from_user_id = ? AND to_user_id = ? AND status = ?", other, me, "pending").First(&p).Error; err == nil {
			rel = "pending_in"
		}
	}

	return &super.GetFriendRelationResp{Relation: rel}, nil
}
