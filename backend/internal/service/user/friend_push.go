package userapp

import (
	"strconv"

	chatbiz "backend/internal/biz/chat"
	"backend/model"
	userv1 "backend/api/user/v1"
)

const (
	friendRequestWSType = "friend_request"

	friendRequestEventIncoming = "incoming"
	friendRequestEventAccepted = "accepted"
	friendRequestEventRejected = "rejected"
)

func pushFriendRequestEvent(toUserID uint, event, requestID string, fromUserID uint) {
	if toUserID == 0 {
		return
	}
	_ = chatbiz.PushToUser(chatbiz.PushInput{
		UserID: strconv.FormatUint(uint64(toUserID), 10),
		Type:   friendRequestWSType,
		Data: map[string]interface{}{
			"event":        event,
			"request_id":   requestID,
			"from_user_id": strconv.FormatUint(uint64(fromUserID), 10),
		},
	})
}

func pushIncomingFriendRequest(view *userv1.FriendRequestView) {
	if view == nil || view.GetToUser() == nil {
		return
	}
	toID, err := strconv.ParseUint(view.GetToUser().GetId(), 10, 64)
	if err != nil || toID == 0 {
		return
	}
	fromID := uint(0)
	if view.GetFromUser() != nil {
		if parsed, err := strconv.ParseUint(view.GetFromUser().GetId(), 10, 64); err == nil {
			fromID = uint(parsed)
		}
	}
	pushFriendRequestEvent(uint(toID), friendRequestEventIncoming, view.GetId(), fromID)
}

func pushFriendRequestResolved(fr *model.FriendRequest, event string) {
	if fr == nil {
		return
	}
	pushFriendRequestEvent(
		fr.FromUserID,
		event,
		strconv.FormatUint(uint64(fr.ID), 10),
		fr.ToUserID,
	)
	// 处理方自己也 bump 一次，便于多端角标同步。
	pushFriendRequestEvent(
		fr.ToUserID,
		event,
		strconv.FormatUint(uint64(fr.ID), 10),
		fr.FromUserID,
	)
}
