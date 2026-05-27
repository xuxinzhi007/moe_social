package userbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/pb/super"
	"backend/utils"

	"gorm.io/gorm"
)

// ConflictError 好友业务冲突（带展示文案）。
type ConflictError struct {
	Message string
}

func (e *ConflictError) Error() string {
	return e.Message
}

// FriendConflict 构造冲突错误。
func FriendConflict(msg string) error {
	return &ConflictError{Message: msg}
}

func parseActorID(raw string) (uint, error) {
	return parseUserIDString(raw)
}

func friendRequestView(ctx context.Context, db *gorm.DB, fr model.FriendRequest) *super.FriendRequestView {
	_, _ = utils.EnsureUserMoeNo(db, fr.FromUserID)
	_, _ = utils.EnsureUserMoeNo(db, fr.ToUserID)
	var fromU, toU model.User
	_ = db.WithContext(ctx).First(&fromU, fr.FromUserID).Error
	_ = db.WithContext(ctx).First(&toU, fr.ToUserID).Error
	return &super.FriendRequestView{
		Id:        strconv.Itoa(int(fr.ID)),
		FromUser:  ModelToProto(&fromU),
		ToUser:    ModelToProto(&toU),
		Status:    fr.Status,
		CreatedAt: fr.CreatedAt.Format(time.RFC3339),
	}
}

func ensureMutualFollow(ctx context.Context, db *gorm.DB, a, b uint) {
	_ = Follow(ctx, db, a, b)
	_ = Follow(ctx, db, b, a)
}

// SendFriendRequest 发起好友申请。
func SendFriendRequest(ctx context.Context, db *gorm.DB, actorID uint, toUserID, toMoeNo string) (*super.FriendRequestView, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	if actorID == 0 {
		return nil, ErrUnauthorized
	}

	toID := uint(0)
	var err error
	if tid := strings.TrimSpace(toUserID); tid != "" {
		toID, err = parseUserIDString(tid)
		if err != nil {
			return nil, ErrInvalidArgument
		}
	} else if moe := strings.TrimSpace(toMoeNo); moe != "" {
		var u model.User
		if err := db.WithContext(ctx).Where("moe_no = ?", moe).First(&u).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return nil, ErrMoeNoNotFound
			}
			return nil, err
		}
		toID = u.ID
	} else {
		return nil, ErrFriendTargetRequired
	}

	if toID == actorID {
		return nil, ErrFriendSelf
	}

	var target model.User
	if err := db.WithContext(ctx).First(&target, toID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}

	var fr model.FriendRequest
	err = db.WithContext(ctx).Where(
		"(from_user_id = ? AND to_user_id = ?) OR (from_user_id = ? AND to_user_id = ?)",
		actorID, toID, toID, actorID,
	).Order("id desc").First(&fr).Error
	if err == nil {
		switch fr.Status {
		case "pending":
			if fr.FromUserID == actorID {
				return nil, FriendConflict("已发送申请，请等待对方处理")
			}
			return nil, FriendConflict("对方已向你发送好友申请，请在好友页处理")
		case "accepted":
			return nil, FriendConflict("你们已经是好友")
		case "rejected":
			if fr.FromUserID == actorID && fr.ToUserID == toID {
				fr.Status = "pending"
				if err := db.WithContext(ctx).Save(&fr).Error; err != nil {
					return nil, err
				}
				view := friendRequestView(ctx, db, fr)
				return view, nil
			}
		}
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	fr = model.FriendRequest{FromUserID: actorID, ToUserID: toID, Status: "pending"}
	if err := db.WithContext(ctx).Create(&fr).Error; err != nil {
		return nil, err
	}
	_ = db.WithContext(ctx).First(&fr, fr.ID).Error
	view := friendRequestView(ctx, db, fr)
	return view, nil
}

// ListIncomingFriendRequests 收到的待处理申请。
func ListIncomingFriendRequests(ctx context.Context, db *gorm.DB, actorID uint) ([]*super.FriendRequestView, error) {
	if actorID == 0 {
		return nil, ErrUnauthorized
	}
	var list []model.FriendRequest
	if err := db.WithContext(ctx).Where("to_user_id = ? AND status = ?", actorID, "pending").
		Order("id desc").Find(&list).Error; err != nil {
		return nil, err
	}
	out := make([]*super.FriendRequestView, 0, len(list))
	for i := range list {
		out = append(out, friendRequestView(ctx, db, list[i]))
	}
	return out, nil
}

// ListOutgoingFriendRequests 发出的待处理申请。
func ListOutgoingFriendRequests(ctx context.Context, db *gorm.DB, actorID uint) ([]*super.FriendRequestView, error) {
	if actorID == 0 {
		return nil, ErrUnauthorized
	}
	var list []model.FriendRequest
	if err := db.WithContext(ctx).Where("from_user_id = ? AND status = ?", actorID, "pending").
		Order("id desc").Find(&list).Error; err != nil {
		return nil, err
	}
	out := make([]*super.FriendRequestView, 0, len(list))
	for i := range list {
		out = append(out, friendRequestView(ctx, db, list[i]))
	}
	return out, nil
}

func loadOwnedPendingRequest(ctx context.Context, db *gorm.DB, me uint, requestID string) (*model.FriendRequest, error) {
	rid, err := parseUserIDString(requestID)
	if err != nil {
		return nil, ErrInvalidArgument
	}
	var fr model.FriendRequest
	if err := db.WithContext(ctx).First(&fr, rid).Error; err != nil {
		return nil, err
	}
	if fr.ToUserID != me || fr.Status != "pending" {
		return nil, ErrFriendRequestInvalid
	}
	return &fr, nil
}

// AcceptFriendRequest 同意申请。
func AcceptFriendRequest(ctx context.Context, db *gorm.DB, actorID uint, requestID string) error {
	if actorID == 0 {
		return ErrUnauthorized
	}
	fr, err := loadOwnedPendingRequest(ctx, db, actorID, requestID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrFriendRequestNotFound
		}
		return err
	}
	fr.Status = "accepted"
	if err := db.WithContext(ctx).Save(fr).Error; err != nil {
		return err
	}
	ensureMutualFollow(ctx, db, fr.FromUserID, fr.ToUserID)
	return nil
}

// RejectFriendRequest 拒绝申请。
func RejectFriendRequest(ctx context.Context, db *gorm.DB, actorID uint, requestID string) error {
	if actorID == 0 {
		return ErrUnauthorized
	}
	fr, err := loadOwnedPendingRequest(ctx, db, actorID, requestID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrFriendRequestNotFound
		}
		return err
	}
	fr.Status = "rejected"
	return db.WithContext(ctx).Save(fr).Error
}

// ListFriends 好友列表。
func ListFriends(ctx context.Context, db *gorm.DB, actorID uint) ([]*super.User, error) {
	if actorID == 0 {
		return nil, ErrUnauthorized
	}
	var list []model.FriendRequest
	if err := db.WithContext(ctx).
		Where("status = ? AND (from_user_id = ? OR to_user_id = ?)", "accepted", actorID, actorID).
		Find(&list).Error; err != nil {
		return nil, err
	}

	seen := make(map[uint]struct{})
	ids := make([]uint, 0)
	for _, fr := range list {
		other := fr.FromUserID
		if other == actorID {
			other = fr.ToUserID
		}
		if _, ok := seen[other]; ok {
			continue
		}
		seen[other] = struct{}{}
		ids = append(ids, other)
	}

	out := make([]*super.User, 0, len(ids))
	for _, id := range ids {
		var u model.User
		if err := db.WithContext(ctx).First(&u, id).Error; err != nil {
			continue
		}
		_, _ = utils.EnsureUserMoeNo(db, u.ID)
		_ = db.WithContext(ctx).First(&u, u.ID).Error
		out = append(out, ModelToProto(&u))
	}
	return out, nil
}

// GetFriendRelation 与另一用户的关系。
func GetFriendRelation(ctx context.Context, db *gorm.DB, actorID, otherID uint) (string, error) {
	if actorID == 0 {
		return "", ErrUnauthorized
	}
	if otherID == 0 {
		return "", ErrInvalidArgument
	}

	rel := "none"
	var acc model.FriendRequest
	q := db.WithContext(ctx).Where(
		"status = ? AND ((from_user_id = ? AND to_user_id = ?) OR (from_user_id = ? AND to_user_id = ?))",
		"accepted", actorID, otherID, otherID, actorID,
	).First(&acc)
	if q.Error == nil {
		rel = "friend"
	} else {
		var p model.FriendRequest
		if err := db.WithContext(ctx).
			Where("from_user_id = ? AND to_user_id = ? AND status = ?", actorID, otherID, "pending").
			First(&p).Error; err == nil {
			rel = "pending_out"
		} else if err := db.WithContext(ctx).
			Where("from_user_id = ? AND to_user_id = ? AND status = ?", otherID, actorID, "pending").
			First(&p).Error; err == nil {
			rel = "pending_in"
		}
	}
	return rel, nil
}

// ParseActorUserID 解析 actor 用户 ID 字符串。
func ParseActorUserID(raw string) (uint, error) {
	id, err := parseActorID(raw)
	if err != nil || id == 0 {
		return 0, ErrUnauthorized
	}
	return id, nil
}
