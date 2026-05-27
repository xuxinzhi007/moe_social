package userbiz

import "errors"

var (
	ErrNotFound              = errors.New("user not found")
	ErrMoeNoNotFound         = errors.New("moe no not found")
	ErrInvalidArgument       = errors.New("invalid argument")
	ErrUnauthorized          = errors.New("unauthorized")
	ErrAlreadyExists         = errors.New("already exists")
	ErrFriendRequestNotFound = errors.New("friend request not found")
	ErrFriendRequestInvalid  = errors.New("friend request invalid")
	ErrFriendSelf            = errors.New("cannot friend self")
	ErrFriendTargetRequired  = errors.New("friend target required")
)
