package behaviorbiz

import "errors"

var (
	ErrInvalidUser  = errors.New("invalid user_id")
	ErrBatchTooLarge = errors.New("events batch too large")
)
