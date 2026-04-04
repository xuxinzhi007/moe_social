// Package logutil 提供认证/审计日志用的安全脱敏，避免把密码、完整邮箱打进日志。
package logutil

import "strings"

// MaskEmail 仅保留邮箱局部前 2 位与域名，便于排查又降低泄露风险。
func MaskEmail(email string) string {
	e := strings.TrimSpace(strings.ToLower(email))
	if e == "" {
		return ""
	}
	at := strings.LastIndex(e, "@")
	if at <= 0 || at == len(e)-1 {
		return "***"
	}
	local, domain := e[:at], e[at+1:]
	if len(local) <= 2 {
		return "***@" + domain
	}
	return local[:2] + "***@" + domain
}

// LoginAttemptTag 描述本次登录用的账号字段（不含密码），用于中文日志。
func LoginAttemptTag(email, username string) string {
	if strings.TrimSpace(email) != "" {
		return "方式=邮箱 账号=" + MaskEmail(email)
	}
	if strings.TrimSpace(username) != "" {
		return "方式=用户名或Moe号 账号=" + strings.TrimSpace(username)
	}
	return "方式=未填写"
}
