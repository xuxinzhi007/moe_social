package common

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
)

// UserIDString 从 go-zero JWT 中间件注入的 context 读取当前用户 ID 字符串。
func UserIDString(ctx context.Context) (string, error) {
	var uidVal interface{}
	if v := ctx.Value("userId"); v != nil {
		uidVal = v
	} else if v := ctx.Value("user_id"); v != nil {
		uidVal = v
	}
	if uidVal == nil {
		return "", errors.New("未登录或 token 无效")
	}
	switch v := uidVal.(type) {
	case string:
		if v == "" {
			return "", errors.New("userId 为空")
		}
		return v, nil
	case json.Number:
		return v.String(), nil
	case float64:
		return fmt.Sprintf("%.0f", v), nil
	default:
		return "", errors.New("userId 类型无效")
	}
}

// UserIDUint 将 JWT context 中的 userId 转为 uint。
func UserIDUint(ctx context.Context) (uint, error) {
	s, err := UserIDString(ctx)
	if err != nil {
		return 0, err
	}
	n, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("userId 无效: %w", err)
	}
	return uint(n), nil
}
