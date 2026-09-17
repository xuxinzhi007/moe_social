package utils

import (
	"net/http"
	"strings"

	"backend/pkg/conf"
)

// ResolveMediaPublicBase 拼图片对外 URL 的 base。
// 注入生效的图片根（含公共地址派生）→ 客户端根 → 请求 Host → 本地兜底。
func ResolveMediaPublicBase(r *http.Request, imagePublicBase, clientPublicBase string) string {
	if u := conf.TrimURL(imagePublicBase); u != "" {
		return u
	}
	if u := conf.TrimURL(clientPublicBase); u != "" {
		return u
	}
	if r != nil {
		host := strings.TrimSpace(r.Host)
		if host != "" && !strings.HasPrefix(host, "0.0.0.0") {
			scheme := "http"
			if r.TLS != nil {
				scheme = "https"
			}
			if proto := strings.TrimSpace(r.Header.Get("X-Forwarded-Proto")); proto != "" {
				scheme = strings.ToLower(strings.TrimSpace(strings.Split(proto, ",")[0]))
			}
			return scheme + "://" + host
		}
	}
	return "http://localhost:8888"
}
