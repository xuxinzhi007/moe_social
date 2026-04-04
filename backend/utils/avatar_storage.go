package utils

import (
	"net/url"
	"strings"
)

// NormalizeAvatarForStorage 将头像字段存为「无 host」形式，避免 cpolar 等隧道域名写入库后他人不可见。
// - 本站图库：统一为 /api/images/{key}
// - data: 外链（如 https://picsum.photos/...）保持原样
func NormalizeAvatarForStorage(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}
	if strings.HasPrefix(s, "data:") {
		return s
	}
	u, err := url.Parse(s)
	if err == nil && u.Scheme != "" && u.Host != "" {
		path := u.Path
		if strings.Contains(path, "/api/images/") {
			out := path
			if u.RawQuery != "" {
				out += "?" + u.RawQuery
			}
			return out
		}
		return s
	}
	if strings.HasPrefix(s, "/api/images/") {
		return s
	}
	// 裸 key：{userId}_{username}__{filename}
	if strings.Contains(s, "__") && !strings.Contains(s, "://") && !strings.Contains(s, "/") {
		return "/api/images/" + s
	}
	return s
}
