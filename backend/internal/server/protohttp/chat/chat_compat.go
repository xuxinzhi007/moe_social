package chathttp

import (
	"context"
	"strings"

	chatv1 "backend/api/chat/v1"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func fillPrivateMessageListRequest(ctx context.Context, in *chatv1.ListPrivateMessagesRequest) error {
	if in == nil {
		return status.Error(codes.InvalidArgument, "request required")
	}
	if strings.TrimSpace(in.GetViewerId()) == "" {
		uid, err := actorUserID(ctx)
		if err != nil {
			return status.Error(codes.Unauthenticated, "请先登录")
		}
		in.ViewerId = uid
	}
	if strings.TrimSpace(in.GetPeerId()) == "" {
		peer := queryFirst(ctx, "peer_user_id", "peerUserId", "peer_id", "peerId")
		if peer == "" {
			return status.Error(codes.InvalidArgument, "peer_user_id required")
		}
		in.PeerId = peer
	}
	return nil
}

func fillPrivateConversationsRequest(ctx context.Context, in *chatv1.ListPrivateConversationsRequest) error {
	if in == nil {
		return status.Error(codes.InvalidArgument, "request required")
	}
	if strings.TrimSpace(in.GetViewerId()) != "" {
		return nil
	}
	uid, err := actorUserID(ctx)
	if err != nil {
		return status.Error(codes.Unauthenticated, "请先登录")
	}
	in.ViewerId = uid
	return nil
}

func fillSendPrivateMessageRequest(ctx context.Context, in *chatv1.SendPrivateMessageRequest) error {
	if in == nil {
		return status.Error(codes.InvalidArgument, "request required")
	}
	uid, err := actorUserID(ctx)
	if err != nil {
		return status.Error(codes.Unauthenticated, "请先登录")
	}
	in.SenderId = uid
	return nil
}

func fillClearPrivateChatHistoryRequest(ctx context.Context, in *chatv1.ClearPrivateChatHistoryReq) error {
	if in == nil {
		return status.Error(codes.InvalidArgument, "request required")
	}
	uid, err := actorUserID(ctx)
	if err != nil {
		return status.Error(codes.Unauthenticated, "请先登录")
	}
	in.ViewerId = uid
	if strings.TrimSpace(in.GetPeerId()) == "" {
		peer := queryFirst(ctx, "peer_user_id", "peerUserId", "peer_id", "peerId")
		if peer == "" {
			return status.Error(codes.InvalidArgument, "peer_user_id required")
		}
		in.PeerId = peer
	}
	return nil
}
