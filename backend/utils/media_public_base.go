package utils

import (
	"net/http"
	"strings"
)

// ResolveMediaPublicBase 拼图片对外 URL 的 base。
// 优先 Image.PublicBaseUrl；否则用当前 HTTP 请求的 Host（Admin 列表与预览同源）；
// 再回退 app_client.public_api_base_url（Flutter 线上地址）。
func ResolveMediaPublicBase(r *http.Request, imagePublicBase, clientPublicBase string) string {
	if u := strings.TrimRight(strings.TrimSpace(imagePublicBase), "/"); u != "" {
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
	if u := strings.TrimRight(strings.TrimSpace(clientPublicBase), "/"); u != "" {
		return u
	}
	return "http://localhost:8888"
}
