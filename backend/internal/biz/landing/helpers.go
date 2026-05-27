package landingbiz

import (
	"strings"
	"unicode/utf8"
)

// NormalizeCategory 落地页反馈分类。
func NormalizeCategory(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "feature":
		return "feature"
	case "bug":
		return "bug"
	default:
		return "other"
	}
}

// TruncateRunes 截断 rune 长度。
func TruncateRunes(s string, max int) string {
	if max <= 0 || s == "" {
		return ""
	}
	if utf8.RuneCountInString(s) <= max {
		return s
	}
	runes := []rune(s)
	return string(runes[:max])
}
