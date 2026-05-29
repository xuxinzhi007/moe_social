package userbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"

	"backend/model"
	userv1 "backend/api/user/v1"
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

func friendRequestView(ctx context.Context, store UserStore, fr model.FriendRequest) *userv1.FriendRequestView {
	_, _ = utils.EnsureUserMoeNo(store.Raw(), fr.FromUserID)
	_, _ = utils.EnsureUserMoeNo(store.Raw(), fr.ToUserID)
	fromU, _ := store.GetUserByID(ctx, fr.FromUserID)
	toU, _ := store.GetUserByID(ctx, fr.ToUserID)
	return &userv1.FriendRequestView{
		Id:        strconv.Itoa(int(fr.ID)),
		FromUser:  ModelToUserV1(&fromU),
		ToUser:    ModelToUserV1(&toU),
		Status:    fr.Status,
		CreatedAt: fr.CreatedAt.Format(time.RFC3339),
	}
}

func ensureMutualFollow(ctx context.Context, store UserStore, a, b uint) {
	_ = Follow(ctx, store, a, b)
	_ = Follow(ctx, store, b, a)
}

// SendFriendRequest 发起好友申请。
func SendFriendRequest(ctx context.Context, store UserStore, actorID uint, toUserID, toMoeNo string) (*userv1.FriendRequestView, error) {
	if store == nil {
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
		u, err := store.FindUserByMoeNo(ctx, moe)
		if err != nil {
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

	if _, err := store.GetUserByID(ctx, toID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}

	fr, found, err := store.FindLatestFriendRequestBetween(ctx, actorID, toID)
	if err != nil {
		return nil, err
	}
	if found {
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
				if err := store.SaveFriendRequest(ctx, &fr); err != nil {
					return nil, err
				}
				view := friendRequestView(ctx, store, fr)
				return view, nil
			}
		}
	}

	fr = model.FriendRequest{FromUserID: actorID, ToUserID: toID, Status: "pending"}
	if err := store.CreateFriendRequest(ctx, &fr); err != nil {
		return nil, err
	}
	fr, _ = store.ReloadFriendRequest(ctx, fr.ID)
	view := friendRequestView(ctx, store, fr)
	return view, nil
}

// ListIncomingFriendRequests 收到的待处理申请。
func ListIncomingFriendRequests(ctx context.Context, store UserStore, actorID uint) ([]*userv1.FriendRequestView, error) {
	if actorID == 0 {
		return nil, ErrUnauthorized
	}
	list, err := store.ListIncomingFriendRequests(ctx, actorID)
	if err != nil {
		return nil, err
	}
	out := make([]*userv1.FriendRequestView, 0, len(list))
	for i := range list {
		out = append(out, friendRequestView(ctx, store, list[i]))
	}
	return out, nil
}

// ListOutgoingFriendRequests 发出的待处理申请。
func ListOutgoingFriendRequests(ctx context.Context, store UserStore, actorID uint) ([]*userv1.FriendRequestView, error) {
	if actorID == 0 {
		return nil, ErrUnauthorized
	}
	list, err := store.ListOutgoingFriendRequests(ctx, actorID)
	if err != nil {
		return nil, err
	}
	out := make([]*userv1.FriendRequestView, 0, len(list))
	for i := range list {
		out = append(out, friendRequestView(ctx, store, list[i]))
	}
	return out, nil
}

func loadOwnedPendingRequest(ctx context.Context, store UserStore, me uint, requestID string) (*model.FriendRequest, error) {
	rid, err := parseUserIDString(requestID)
	if err != nil {
		return nil, ErrInvalidArgument
	}
	fr, err := store.GetFriendRequestByID(ctx, rid)
	if err != nil {
		return nil, err
	}
	if fr.ToUserID != me || fr.Status != "pending" {
		return nil, ErrFriendRequestInvalid
	}
	return &fr, nil
}

// AcceptFriendRequest 同意申请。
func AcceptFriendRequest(ctx context.Context, store UserStore, actorID uint, requestID string) error {
	if actorID == 0 {
		return ErrUnauthorized
	}
	fr, err := loadOwnedPendingRequest(ctx, store, actorID, requestID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrFriendRequestNotFound
		}
		return err
	}
	fr.Status = "accepted"
	if err := store.SaveFriendRequest(ctx, fr); err != nil {
		return err
	}
	ensureMutualFollow(ctx, store, fr.FromUserID, fr.ToUserID)
	return nil
}

// RejectFriendRequest 拒绝申请。
func RejectFriendRequest(ctx context.Context, store UserStore, actorID uint, requestID string) error {
	if actorID == 0 {
		return ErrUnauthorized
	}
	fr, err := loadOwnedPendingRequest(ctx, store, actorID, requestID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrFriendRequestNotFound
		}
		return err
	}
	fr.Status = "rejected"
	return store.SaveFriendRequest(ctx, fr)
}

// ListFriends 好友列表。
func ListFriends(ctx context.Context, store UserStore, actorID uint) ([]*userv1.User, error) {
	if actorID == 0 {
		return nil, ErrUnauthorized
	}
	list, err := store.ListAcceptedFriendRequests(ctx, actorID)
	if err != nil {
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

	out := make([]*userv1.User, 0, len(ids))
	for _, id := range ids {
		u, err := store.GetUserByID(ctx, id)
		if err != nil {
			continue
		}
		_, _ = utils.EnsureUserMoeNo(store.Raw(), u.ID)
		u, _ = store.ReloadUser(ctx, u.ID)
		out = append(out, ModelToUserV1(&u))
	}
	return out, nil
}

// GetFriendRelation 与另一用户的关系。
func GetFriendRelation(ctx context.Context, store UserStore, actorID, otherID uint) (string, error) {
	if actorID == 0 {
		return "", ErrUnauthorized
	}
	if otherID == 0 {
		return "", ErrInvalidArgument
	}

	rel := "none"
	_, found, err := store.FindAcceptedFriendRelation(ctx, actorID, otherID)
	if err != nil {
		return "", err
	}
	if found {
		rel = "friend"
	} else {
		_, pendingOut, _ := store.FindPendingFriendRequest(ctx, actorID, otherID)
		if pendingOut {
			rel = "pending_out"
		} else {
			_, pendingIn, _ := store.FindPendingFriendRequest(ctx, otherID, actorID)
			if pendingIn {
				rel = "pending_in"
			}
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
