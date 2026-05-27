package vipbiz

import "errors"

var (
	// ErrNotFound VIP 套餐不存在。
	ErrNotFound = errors.New("vip plan not found")
	// ErrInvalidArgument 参数无效。
	ErrInvalidArgument = errors.New("invalid argument")
)
