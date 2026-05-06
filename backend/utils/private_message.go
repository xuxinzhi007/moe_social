package utils

import (
	"time"

	"backend/model"

	"github.com/spf13/viper"
)

// PrivateMessageRetentionDaysForSender 按发送方当前 VIP 状态计算消息保留天数（写入 ExpiresAt 时快照 RetentionDays）。
func PrivateMessageRetentionDaysForSender(u *model.User) int {
	if u.MessageRetentionChoice == 7 || u.MessageRetentionChoice == 30 {
		return u.MessageRetentionChoice
	}
	vip := u.IsVip && u.VipEndAt != nil && u.VipEndAt.After(time.Now())
	if vip {
		d := viper.GetInt("private_message.retention_days_vip")
		if d <= 0 {
			d = 90
		}
		return d
	}
	d := viper.GetInt("private_message.retention_days_normal")
	if d <= 0 {
		d = viper.GetInt("private_message.retention_days_default")
	}
	if d <= 0 {
		d = 30
	}
	return d
}

// PrivateMessageBodyMaxRunes 单条正文最大字符数（rune），未配置则 8000。
func PrivateMessageBodyMaxRunes() int {
	n := viper.GetInt("private_message.body_max_runes")
	if n <= 0 {
		return 8000
	}
	return n
}

// PrivateMessageImagePathsMax 每条消息最多附带图片路径条数。
func PrivateMessageImagePathsMax() int {
	n := viper.GetInt("private_message.image_paths_max")
	if n <= 0 {
		return 9
	}
	return n
}
