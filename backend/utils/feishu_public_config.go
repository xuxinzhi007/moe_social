package utils

import (
	"strings"

	"github.com/spf13/viper"
)

// FeishuPublicConfig 给前端的飞书说明（无需登录）。
type FeishuPublicConfig struct {
	Enabled             bool   `json:"enabled"`
	EnterpriseInviteURL string `json:"enterprise_invite_url,omitempty"`
	Notice              string `json:"notice,omitempty"`
}

// GetFeishuPublicConfig 飞书能力为可选；机器人仅企业内可用。
func GetFeishuPublicConfig() FeishuPublicConfig {
	notice := strings.TrimSpace(viper.GetString("feishu.enterprise_notice"))
	if notice == "" {
		notice = "自建应用机器人仅可向企业内成员发送 IM 通知。如需接收角色卡等推送，可申请加入企业（非强制）。"
	}
	return FeishuPublicConfig{
		Enabled:             viper.GetBool("feishu.enabled"),
		EnterpriseInviteURL: strings.TrimSpace(viper.GetString("feishu.enterprise_invite_url")),
		Notice:              notice,
	}
}
