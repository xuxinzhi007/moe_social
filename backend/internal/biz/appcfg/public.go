package appcfgbiz

import (
	"errors"

	"backend/pkg/conf"
)

// ErrNoPublicAPIBaseURL 未配置客户端公网 API 基址。
var ErrNoPublicAPIBaseURL = errors.New("public api base url not configured")

// NormalizePublicAPIBaseURL 去尾斜杠并校验非空。
//
// 规范化委托给 conf.TrimURL：这里处理的 public_base_url 与管理台读写的是同一个值，
// 而仓里曾同时存在三份逐字节相同的「TrimSpace + 去尾斜杠」循环（这里、pkg/conf、utils）。
// 单独改动任何一份，/api/public/client-config 返回的基址就会与管理台显示的不一致 ——
// 这种分歧不报错，只会让人照着界面上的值去排查一个不存在的问题。
//
// 与旧实现有一处**刻意**的差别：输入 "/" 时旧实现先判空、后去斜杠，于是返回 ("", nil)，
// 客户端拿到 HTTP 200 和一个空基址，静默拼不出任何请求。现在统一返回
// ErrNoPublicAPIBaseURL，走调用方 platform.go 已有的 404 NO_PUBLIC_API_BASE_URL 分支。
func NormalizePublicAPIBaseURL(raw string) (string, error) {
	url := conf.TrimURL(raw)
	if url == "" {
		return "", ErrNoPublicAPIBaseURL
	}
	return url, nil
}
