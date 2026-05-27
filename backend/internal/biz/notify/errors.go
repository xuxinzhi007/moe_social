package notifybiz

import "errors"

var (
	ErrEmptyContent        = errors.New("empty notification content")
	ErrInvalidUserID       = errors.New("invalid user id")
	ErrUserNotFound        = errors.New("user not found")
	ErrInvalidNotificationID = errors.New("invalid notification id")
)
