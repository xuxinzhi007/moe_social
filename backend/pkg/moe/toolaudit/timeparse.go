package toolaudit

import (
	"strings"
	"time"
)

// ParseTimeFilter 解析管理台 from/to（支持 RFC3339 或 YYYY-MM-DD）。
func ParseTimeFilter(raw string, endOfDay bool) *time.Time {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	layouts := []string{
		time.RFC3339,
		"2006-01-02 15:04:05",
		"2006-01-02",
	}
	for _, layout := range layouts {
		if t, err := time.ParseInLocation(layout, raw, time.Local); err == nil {
			if layout == "2006-01-02" && endOfDay {
				next := t.Add(24 * time.Hour)
				return &next
			}
			return &t
		}
	}
	return nil
}
