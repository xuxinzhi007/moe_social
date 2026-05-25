package utils

import (
	"fmt"
	"strings"

	"github.com/spf13/viper"
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

func wechatFlowCredentials(flow string) (appID, appSecret string, err error) {
	flow = NormalizeWechatOAuthFlow(flow)
	if flow == "" {
		return "", "", fmt.Errorf("unknown wechat oauth flow")
	}
	switch flow {
	case "app":
		appID = firstNonEmptyConfig(
			"wechat.app.app_id",
			"wechat.mobile_app_id",
			"wechat.mobile.app_id",
		)
		appSecret = firstNonEmptyConfig(
			"wechat.app.app_secret",
			"wechat.mobile_app_secret",
			"wechat.mobile.app_secret",
		)
		// 勿回退公众号(mp)：移动应用 code 只能用 wechat.app 凭证换取，混用会报 10005「公众号没有 scope 权限」
	case "website":
		appID = firstNonEmptyConfig(
			"wechat.website.app_id",
			"wechat.web_app_id",
		)
		appSecret = firstNonEmptyConfig(
			"wechat.website.app_secret",
			"wechat.web_app_secret",
		)
	case "mp":
		appID = firstNonEmptyConfig(
			"wechat.mp.app_id",
			"wechat.mp_app_id",
			"wechat.app_id",
		)
		appSecret = firstNonEmptyConfig(
			"wechat.mp.app_secret",
			"wechat.mp_app_secret",
			"wechat.app_secret",
		)
	}
	if appID == "" || appSecret == "" {
		return "", "", fmt.Errorf("wechat %s credentials missing in config.yaml", flow)
	}
	return appID, appSecret, nil
}

func firstNonEmptyConfig(keys ...string) string {
	for _, k := range keys {
		if v := strings.TrimSpace(viper.GetString(k)); v != "" {
			return v
		}
	}
	return ""
}
