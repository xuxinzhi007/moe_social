package utils

import (
	"net/url"
	"strings"

	"github.com/spf13/viper"
)

// BuildWechatOAuthReturnURL 公众号授权成功后跳回 Web/App（state 由客户端传入）。
func BuildWechatOAuthReturnURL(state, code string) string {
	code = strings.TrimSpace(code)
	if code == "" {
		return ""
	}
	target := strings.TrimSpace(state)
	if !isAllowedWechatReturnURL(target) {
		target = strings.TrimSpace(viper.GetString("wechat.app_return_url"))
	}
	if target == "" {
		return ""
	}
	u, err := url.Parse(target)
	if err != nil {
		return ""
	}
	q := u.Query()
	q.Set("wechat_code", code)
	u.RawQuery = q.Encode()
	return u.String()
}

func isAllowedWechatReturnURL(raw string) bool {
	raw = strings.TrimSpace(raw)
	if raw == "" || raw == "moe_app" || raw == "moe_login" {
		return false
	}
	u, err := url.Parse(raw)
	if err != nil || u.Scheme == "" || u.Host == "" {
		return false
	}
	switch u.Scheme {
	case "http", "https":
		return true
	case "moesocial":
		return u.Host == "wechat"
	default:
		return false
	}
}
