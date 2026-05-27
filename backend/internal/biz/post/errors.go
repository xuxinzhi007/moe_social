package postbiz

import "errors"

var (
	ErrInvalidPostID    = errors.New("invalid post id")
	ErrPostNotFound     = errors.New("post not found")
	ErrEmptyUserID      = errors.New("empty user id")
	ErrInvalidUserID    = errors.New("invalid user id")
	ErrUserNotFound     = errors.New("user not found")
	ErrEmptyPostContent = errors.New("empty post content")
	ErrInvalidGroupID   = errors.New("invalid group id")
	ErrGroupNotFound    = errors.New("group not found")
	ErrNotGroupMember   = errors.New("not group member")
	ErrNotPostOwner     = errors.New("not post owner")
	ErrEmptyReason      = errors.New("empty reason")
	ErrEmptyReporterID  = errors.New("empty reporter id")
)
