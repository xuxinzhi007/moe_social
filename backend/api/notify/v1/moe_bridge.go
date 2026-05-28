package notifyv1

import "backend/rpc/pb/moe"

func NotificationFromMoe(n *moe.Notification) *Notification {
	if n == nil {
		return nil
	}
	return &Notification{
		Id: n.GetId(), UserId: n.GetUserId(), SenderId: n.GetSenderId(),
		SenderName: n.GetSenderName(), SenderAvatar: n.GetSenderAvatar(),
		Type: n.GetType(), PostId: n.GetPostId(), Content: n.GetContent(),
		IsRead: n.GetIsRead(), CreatedAt: n.GetCreatedAt(),
	}
}

func NotificationToMoe(n *Notification) *moe.Notification {
	if n == nil {
		return nil
	}
	return &moe.Notification{
		Id: n.GetId(), UserId: n.GetUserId(), SenderId: n.GetSenderId(),
		SenderName: n.GetSenderName(), SenderAvatar: n.GetSenderAvatar(),
		Type: n.GetType(), PostId: n.GetPostId(), Content: n.GetContent(),
		IsRead: n.GetIsRead(), CreatedAt: n.GetCreatedAt(),
	}
}

func NotificationsFromMoe(items []*moe.Notification) []*Notification {
	if len(items) == 0 {
		return nil
	}
	out := make([]*Notification, 0, len(items))
	for _, n := range items {
		if n == nil {
			continue
		}
		out = append(out, NotificationFromMoe(n))
	}
	return out
}

func NotificationsToMoe(items []*Notification) []*moe.Notification {
	if len(items) == 0 {
		return nil
	}
	out := make([]*moe.Notification, 0, len(items))
	for _, n := range items {
		out = append(out, NotificationToMoe(n))
	}
	return out
}

func GetNotificationsRequestFromMoe(in *moe.GetNotificationsReq) *GetNotificationsRequest {
	if in == nil {
		return &GetNotificationsRequest{}
	}
	return &GetNotificationsRequest{
		UserId: in.GetUserId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
	}
}

func GetNotificationsRequestToMoe(in *GetNotificationsRequest) *moe.GetNotificationsReq {
	if in == nil {
		return &moe.GetNotificationsReq{}
	}
	return &moe.GetNotificationsReq{
		UserId: in.GetUserId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
	}
}

func GetNotificationsReplyFromMoe(out *moe.GetNotificationsResp) *GetNotificationsReply {
	if out == nil {
		return &GetNotificationsReply{}
	}
	return &GetNotificationsReply{
		Notifications: NotificationsFromMoe(out.GetNotifications()),
		Total:         out.GetTotal(),
	}
}

func GetNotificationsReplyToMoe(out *GetNotificationsReply) *moe.GetNotificationsResp {
	if out == nil {
		return &moe.GetNotificationsResp{}
	}
	return &moe.GetNotificationsResp{
		Notifications: NotificationsToMoe(out.GetNotifications()),
		Total:         out.GetTotal(),
	}
}

func GetUnreadCountRequestFromMoe(in *moe.GetUnreadCountReq) *GetUnreadCountRequest {
	if in == nil {
		return &GetUnreadCountRequest{}
	}
	return &GetUnreadCountRequest{UserId: in.GetUserId()}
}

func GetUnreadCountRequestToMoe(in *GetUnreadCountRequest) *moe.GetUnreadCountReq {
	if in == nil {
		return &moe.GetUnreadCountReq{}
	}
	return &moe.GetUnreadCountReq{UserId: in.GetUserId()}
}

func GetUnreadCountReplyFromMoe(out *moe.GetUnreadCountResp) *GetUnreadCountReply {
	if out == nil {
		return &GetUnreadCountReply{}
	}
	return &GetUnreadCountReply{Count: out.GetCount()}
}

func GetUnreadCountReplyToMoe(out *GetUnreadCountReply) *moe.GetUnreadCountResp {
	if out == nil {
		return &moe.GetUnreadCountResp{}
	}
	return &moe.GetUnreadCountResp{Count: out.GetCount()}
}

func ReadNotificationRequestFromMoe(in *moe.ReadNotificationReq) *ReadNotificationRequest {
	if in == nil {
		return &ReadNotificationRequest{}
	}
	return &ReadNotificationRequest{Id: in.GetId(), UserId: in.GetUserId()}
}

func ReadNotificationRequestToMoe(in *ReadNotificationRequest) *moe.ReadNotificationReq {
	if in == nil {
		return &moe.ReadNotificationReq{}
	}
	return &moe.ReadNotificationReq{Id: in.GetId(), UserId: in.GetUserId()}
}

func ReadAllNotificationsRequestFromMoe(in *moe.ReadAllNotificationsReq) *ReadAllNotificationsRequest {
	if in == nil {
		return &ReadAllNotificationsRequest{}
	}
	return &ReadAllNotificationsRequest{UserId: in.GetUserId()}
}

func ReadAllNotificationsRequestToMoe(in *ReadAllNotificationsRequest) *moe.ReadAllNotificationsReq {
	if in == nil {
		return &moe.ReadAllNotificationsReq{}
	}
	return &moe.ReadAllNotificationsReq{UserId: in.GetUserId()}
}
