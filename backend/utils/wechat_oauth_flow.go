package utils

import (
	"strings"
)

// NormalizeWechatOAuthFlow 统一 flow：app/mobile、website/qr、mp。
func NormalizeWechatOAuthFlow(flow string) string {
	switch strings.ToLower(strings.TrimSpace(flow)) {
	case "app", "mobile":
		return "app"
	case "website", "qr", "scan":
		return "website"
	case "mp", "oa", "official":
		return "mp"
	default:
		return ""
	}
}
