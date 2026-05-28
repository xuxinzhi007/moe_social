package handlerutil

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
)

// CtxUserIDString 从 JWT 中间件注入的 context 读取当前用户 ID。
func CtxUserIDString(ctx context.Context) (string, error) {
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
