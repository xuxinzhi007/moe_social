package chathttp

import (
	"errors"

	chatbiz "backend/internal/biz/chat"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errChatAppNil = status.Error(codes.FailedPrecondition, "ChatApp 未初始化")

func mapChatError(err error) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, chatbiz.ErrInvalidSenderID),
		errors.Is(err, chatbiz.ErrInvalidViewerID):
		return status.Error(codes.Unauthenticated, "请先登录")
	case errors.Is(err, chatbiz.ErrInvalidReceiverID),
		errors.Is(err, chatbiz.ErrInvalidPeerID),
		errors.Is(err, chatbiz.ErrInvalidBeforeID):
		return status.Error(codes.InvalidArgument, "私信参数无效")
	case errors.Is(err, chatbiz.ErrMessageSelf):
		return status.Error(codes.InvalidArgument, "不能给自己发送私信")
	case errors.Is(err, chatbiz.ErrEmptyMessageBody):
		return status.Error(codes.InvalidArgument, "请输入要发送的内容")
	case errors.Is(err, chatbiz.ErrMessageBodyTooLong):
		return status.Error(codes.InvalidArgument, "消息内容太长了")
	case errors.Is(err, chatbiz.ErrTooManyImagePaths):
		return status.Error(codes.InvalidArgument, "一次最多发送 9 张图片")
	case errors.Is(err, chatbiz.ErrInvalidImagePath):
		return status.Error(codes.InvalidArgument, "图片参数无效")
	case errors.Is(err, chatbiz.ErrUserNotFound):
		return status.Error(codes.NotFound, "用户不存在")
	case errors.Is(err, chatbiz.ErrPeerNotFound):
		return status.Error(codes.NotFound, "对方用户不存在")
	case errors.Is(err, chatbiz.ErrChatStoreUnavailable):
		return status.Error(codes.FailedPrecondition, "私信服务暂不可用")
	case errors.Is(err, chatbiz.ErrSaveMessage),
		errors.Is(err, chatbiz.ErrQueryMessages):
		return status.Error(codes.Internal, "私信服务忙，请稍后再试")
	default:
		return err
	}
}
