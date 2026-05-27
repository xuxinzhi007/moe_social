package appcfgbiz

import (
	"errors"
	"strings"
)

// ErrNoPublicAPIBaseURL 未配置客户端公网 API 基址。
var ErrNoPublicAPIBaseURL = errors.New("public api base url not configured")

// NormalizePublicAPIBaseURL 去尾斜杠并校验非空。
func NormalizePublicAPIBaseURL(raw string) (string, error) {
	url := strings.TrimSpace(raw)
	if url == "" {
		return "", ErrNoPublicAPIBaseURL
	}
	for strings.HasSuffix(url, "/") {
		url = strings.TrimSuffix(url, "/")
	}
	return url, nil
}
