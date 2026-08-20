package giftbiz

import "errors"

var (
	ErrInvalidGiftRequest = errors.New("invalid gift request")
	ErrEmptyGiftID       = errors.New("empty gift id")
	ErrInvalidGiftID     = errors.New("invalid gift id")
	ErrInvalidUserID     = errors.New("invalid user id")
	ErrUserNotFound      = errors.New("user not found")
	ErrGiftNotFound      = errors.New("gift not found")
	ErrInsufficientBal   = errors.New("insufficient balance")
	ErrInvalidSenderID   = errors.New("invalid sender id")
	ErrInvalidReceiverID = errors.New("invalid receiver id")
)
