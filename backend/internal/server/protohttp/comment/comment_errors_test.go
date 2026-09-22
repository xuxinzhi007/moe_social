package commenthttp

import (
	"testing"

	commentbiz "backend/internal/biz/comment"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestMapCommentErrorForCreateRules(t *testing.T) {
	for _, tc := range []struct {
		name string
		err  error
		code codes.Code
		msg  string
	}{
		{name: "empty", err: commentbiz.ErrEmptyContent, code: codes.InvalidArgument, msg: "请输入评论内容"},
		{name: "parent missing", err: commentbiz.ErrParentNotFound, code: codes.NotFound, msg: "要回复的评论不存在"},
		{name: "parent mismatch", err: commentbiz.ErrParentMismatch, code: codes.InvalidArgument, msg: "回复不属于当前帖子"},
		{name: "login", err: commentbiz.ErrInvalidUserID, code: codes.Unauthenticated, msg: "请先登录"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			err := mapCommentError(tc.err)
			if status.Code(err) != tc.code {
				t.Fatalf("code=%v want %v", status.Code(err), tc.code)
			}
			if status.Convert(err).Message() != tc.msg {
				t.Fatalf("message=%q want %q", status.Convert(err).Message(), tc.msg)
			}
		})
	}
}
