package commentbiz

import "errors"

var (
	ErrInvalidPostID     = errors.New("invalid post id")
	ErrInvalidUserID     = errors.New("invalid user id")
	ErrPostNotFound      = errors.New("post not found")
	ErrUserNotFound      = errors.New("user not found")
	ErrInvalidParentID   = errors.New("invalid parent id")
	ErrParentNotFound    = errors.New("parent comment not found")
	ErrParentMismatch    = errors.New("parent comment mismatch")
	ErrInvalidCommentID  = errors.New("invalid comment id")
	ErrCommentNotFound   = errors.New("comment not found")
)
