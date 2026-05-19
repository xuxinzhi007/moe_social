package utils

import (
	"net/url"
	"strings"

	"github.com/spf13/viper"
)

// BuildFeishuOAuthReturnURL 授权成功后跳回 App（state 由客户端传入当前页 origin）。
func BuildFeishuOAuthReturnURL(state, code string) string {
	code = strings.TrimSpace(code)
	if code == "" {
		return ""
	}
	target := strings.TrimSpace(state)
	if !isAllowedReturnURL(target) {
		target = strings.TrimSpace(viper.GetString("feishu.app_return_url"))
	}
	if target == "" {
		return ""
	}
	u, err := url.Parse(target)
	if err != nil {
		return ""
	}
	q := u.Query()
	q.Set("feishu_code", code)
	u.RawQuery = q.Encode()
	return u.String()
}

func isAllowedReturnURL(raw string) bool {
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
		// App 原生授权完成后由服务端 302 带回（state=moesocial://feishu/oauth）。
		return u.Host == "feishu"
	default:
		return false
	}
}
