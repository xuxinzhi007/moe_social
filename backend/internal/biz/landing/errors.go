package landingbiz

import "errors"

var (
	ErrInvalidEmail    = errors.New("invalid email")
	ErrInvalidArgument = errors.New("invalid argument")
	ErrTooLong         = errors.New("content too long")
	ErrRateLimited     = errors.New("rate limited")
)
