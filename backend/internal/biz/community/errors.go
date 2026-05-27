package communitybiz

import "errors"

var (
	ErrInvalidGroupID = errors.New("invalid group id")
	ErrInvalidUserID  = errors.New("invalid user id")
	ErrInvalidPostID  = errors.New("invalid post id")
	ErrGroupNotFound  = errors.New("group not found")
	ErrNotMember      = errors.New("not group member")
	ErrPrivateGroup   = errors.New("private group")
	ErrPostNotFound   = errors.New("post not found")
	ErrNotPostAuthor  = errors.New("not post author")
)
