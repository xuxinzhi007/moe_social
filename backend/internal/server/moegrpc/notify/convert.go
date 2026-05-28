package notifygrpc

import (
	notifyv1 "backend/api/notify/v1"
	moerpc "backend/rpc/pb/moe"
)

func notificationsToProto(items []*moerpc.Notification) []*notifyv1.Notification {
	if len(items) == 0 {
		return nil
	}
	out := make([]*notifyv1.Notification, 0, len(items))
	for _, n := range items {
		out = append(out, notificationToProto(n))
	}
	return out
}

func notificationToProto(n *moerpc.Notification) *notifyv1.Notification {
	if n == nil {
		return nil
	}
	return &notifyv1.Notification{
		Id: n.GetId(), UserId: n.GetUserId(), SenderId: n.GetSenderId(),
		SenderName: n.GetSenderName(), SenderAvatar: n.GetSenderAvatar(),
		Type: n.GetType(), PostId: n.GetPostId(), Content: n.GetContent(),
		IsRead: n.GetIsRead(), CreatedAt: n.GetCreatedAt(),
	}
}
