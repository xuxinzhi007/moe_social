package chathttp

import (
	"fmt"
	"testing"

	chatbiz "backend/internal/biz/chat"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestMapChatErrorForPrivateMessageRules(t *testing.T) {
	for _, tc := range []struct {
		name string
		err  error
		code codes.Code
		msg  string
	}{
		{name: "login", err: chatbiz.ErrInvalidSenderID, code: codes.Unauthenticated, msg: "请先登录"},
		{name: "empty", err: chatbiz.ErrEmptyMessageBody, code: codes.InvalidArgument, msg: "请输入要发送的内容"},
		{name: "self", err: chatbiz.ErrMessageSelf, code: codes.InvalidArgument, msg: "不能给自己发送私信"},
		{name: "peer missing", err: chatbiz.ErrPeerNotFound, code: codes.NotFound, msg: "对方用户不存在"},
		{name: "wrapped peer missing", err: fmt.Errorf("clear: %w", chatbiz.ErrPeerNotFound), code: codes.NotFound, msg: "对方用户不存在"},
		{name: "query failed", err: chatbiz.ErrQueryMessages, code: codes.Internal, msg: "私信服务忙，请稍后再试"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			err := mapChatError(tc.err)
			if status.Code(err) != tc.code {
				t.Fatalf("code=%v want %v", status.Code(err), tc.code)
			}
			if status.Convert(err).Message() != tc.msg {
				t.Fatalf("message=%q want %q", status.Convert(err).Message(), tc.msg)
			}
		})
	}
}
