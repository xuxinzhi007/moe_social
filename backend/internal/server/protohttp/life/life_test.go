package lifehttp

import "testing"

func TestExtractRetrySeconds(t *testing.T) {
	tests := []struct {
		name string
		msg  string
		want float64
	}{
		{
			name: "正常整数秒",
			msg:  "action in cooldown, retry after 3 seconds",
			want: 3,
		},
		{
			name: "正常小数秒（向上取整）",
			msg:  "action in cooldown, retry after 2.3 seconds",
			want: 3,
		},
		{
			name: "较大值",
			msg:  "action in cooldown, retry after 15 seconds",
			want: 15,
		},
		{
			name: "亚秒值（<1 应返回 1）",
			msg:  "action in cooldown, retry after 0.3 seconds",
			want: 1,
		},
		{
			name: "恰好 1 秒",
			msg:  "action in cooldown, retry after 1 seconds",
			want: 1,
		},
		{
			name: "恰好 0 秒（<1 应返回 1）",
			msg:  "action in cooldown, retry after 0 seconds",
			want: 1,
		},
		{
			name: "空消息（解析失败，返回默认 3）",
			msg:  "",
			want: 3,
		},
		{
			name: "格式不匹配（返回默认 3）",
			msg:  "some random error",
			want: 3,
		},
		{
			name: "消息被截断（返回默认 3）",
			msg:  "action in cooldown, retry after",
			want: 3,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := extractRetrySeconds(tt.msg)
			if got != tt.want {
				t.Errorf("extractRetrySeconds(%q) = %v, want %v", tt.msg, got, tt.want)
			}
		})
	}
}
