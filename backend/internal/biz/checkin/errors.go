package checkinbiz

import "errors"

var (
	ErrInvalidUserID    = errors.New("invalid user id")
	ErrUserNotFound     = errors.New("user not found")
	ErrAlreadyCheckedIn = errors.New("already checked in today")
)
