package posthttp

import (
	"testing"

	postbiz "backend/internal/biz/post"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestMapPostErrorForGroupMemberRule(t *testing.T) {
	err := mapPostError(postbiz.ErrNotGroupMember)
	if status.Code(err) != codes.PermissionDenied {
		t.Fatalf("code=%v err=%v", status.Code(err), err)
	}
	if status.Convert(err).Message() != "请先加入该群组再发帖" {
		t.Fatalf("message=%q", status.Convert(err).Message())
	}
}

func TestMapPostErrorForInvalidCreateInput(t *testing.T) {
	for _, tc := range []struct {
		name string
		err  error
		code codes.Code
	}{
		{name: "empty content", err: postbiz.ErrEmptyPostContent, code: codes.InvalidArgument},
		{name: "group not found", err: postbiz.ErrGroupNotFound, code: codes.NotFound},
		{name: "invalid user", err: postbiz.ErrInvalidUserID, code: codes.Unauthenticated},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := status.Code(mapPostError(tc.err)); got != tc.code {
				t.Fatalf("code=%v want %v", got, tc.code)
			}
		})
	}
}
