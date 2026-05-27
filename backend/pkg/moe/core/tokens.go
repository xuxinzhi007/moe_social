package core

import "strings"

// EstimateTokens 粗略 token 估算（约 4 字符/token）。
func EstimateTokens(text string) int {
	n := len([]rune(strings.TrimSpace(text)))
	if n <= 0 {
		return 0
	}
	t := n / 4
	if t < 1 {
		return 1
	}
	return t
}
