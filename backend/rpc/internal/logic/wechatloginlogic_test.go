package logic

import "testing"

func TestNormalizeWechatDisplayName(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		in   string
		want string
	}{
		{name: "chinese nickname", in: "  小明  ", want: "小明"},
		{name: "mixed nickname", in: "Moe_酱", want: "Moe_酱"},
		{name: "control chars stripped", in: "A\u0000B", want: "AB"},
		{name: "empty", in: "   ", want: ""},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			if got := normalizeWechatDisplayName(tt.in); got != tt.want {
				t.Fatalf("normalizeWechatDisplayName(%q) = %q, want %q", tt.in, got, tt.want)
			}
		})
	}
}

func TestIsAutoWechatUsername(t *testing.T) {
	t.Parallel()

	if !isAutoWechatUsername("wx_a3f2b1") {
		t.Fatal("expected wx_ prefix username to be auto")
	}
	if !isAutoWechatUsername("wechat_user_ab12cd") {
		t.Fatal("expected wechat_user prefix username to be auto")
	}
	if isAutoWechatUsername("小明") {
		t.Fatal("expected chinese nickname username not to be auto")
	}
}
