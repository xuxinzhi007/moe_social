package model

import "strings"

// IsTechnicalUserMemory 判断是否为设备同步等技术项，不属于对话记忆。
// 与 backend/pkg/memory.IsTechnical 规则一致（model 包不可 import pkg/memory，避免循环依赖）。
func IsTechnicalUserMemory(key, source string) bool {
	k := strings.ToLower(strings.TrimSpace(key))
	s := strings.ToLower(strings.TrimSpace(source))
	if strings.HasPrefix(k, "device_info:") || s == "device_sync" {
		return true
	}
	// OpenClaw 日记层：仅用于 prompt 注入，不在「记忆库」列表展示。
	if strings.HasPrefix(k, "daily_note:") {
		return true
	}
	return false
}
