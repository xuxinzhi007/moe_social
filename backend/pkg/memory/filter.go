package memory

import "strings"

// IsTechnical 设备同步等技术项，不属于对话记忆。
func IsTechnical(key, source string) bool {
	k := strings.ToLower(strings.TrimSpace(key))
	s := strings.ToLower(strings.TrimSpace(source))
	return strings.HasPrefix(k, "device_info:") || s == "device_sync"
}

// IsNoiseValue 无意义的占位 value，不参与检索与画像。
func IsNoiseValue(value string) bool {
	norm := strings.ToLower(strings.TrimSpace(value))
	if norm == "" {
		return true
	}
	switch norm {
	case "-", "--", "/", "n/a", "na", "none", "null", "nil", "unknown", "无", "未知", "未提及", "不知道":
		return true
	}
	return false
}

// FacingRecords 过滤出可面向用户/对话使用的记忆。
func FacingRecords(records []Record) []Record {
	out := make([]Record, 0, len(records))
	for _, r := range records {
		key := strings.TrimSpace(r.Key)
		val := strings.TrimSpace(r.Value)
		if key == "" || val == "" {
			continue
		}
		if IsTechnical(key, r.Source) || IsNoiseValue(val) {
			continue
		}
		out = append(out, r)
	}
	return out
}
