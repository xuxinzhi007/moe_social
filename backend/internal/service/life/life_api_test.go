package lifeapp

import "testing"

func TestExtractRetrySeconds(t *testing.T) {
	tests := []struct {
		name string
		msg  string
		want float64
	}{
		{name: "正常整数秒", msg: "action in cooldown, retry after 3 seconds", want: 3},
		{name: "正常小数秒", msg: "action in cooldown, retry after 2.3 seconds", want: 3},
		{name: "格式不匹配", msg: "some random error", want: 3},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := extractRetrySeconds(tt.msg); got != tt.want {
				t.Errorf("extractRetrySeconds(%q) = %v, want %v", tt.msg, got, tt.want)
			}
		})
	}
}
