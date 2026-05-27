package vipbiz

import (
	"strconv"
	"strings"
)

// ParsePlanID 解析套餐 ID 字符串。
func ParsePlanID(raw string) (uint, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, ErrInvalidArgument
	}
	n, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || n == 0 {
		return 0, ErrInvalidArgument
	}
	return uint(n), nil
}
