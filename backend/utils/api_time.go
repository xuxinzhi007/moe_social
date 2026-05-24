package utils

import "time"

// FormatAPIDateTime 以 RFC3339（UTC）返回，供客户端正确解析时区。
func FormatAPIDateTime(t time.Time) string {
	return t.UTC().Format(time.RFC3339)
}
