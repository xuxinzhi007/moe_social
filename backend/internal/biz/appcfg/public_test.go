package appcfgbiz

import (
	"errors"
	"testing"

	"backend/pkg/conf"
)

// TestNormalizePublicAPIBaseURL 钉住 /api/public/client-config 返回给客户端的基址形状。
//
// 这条路径此前**零测试覆盖**：整个 appcfgbiz 包只有一个 21 行的函数，没有任何用例。
// 而它的输出会被 Flutter 直接拿去拼所有图片与接口地址，拼错不报错，只表现为「图片全裂」。
//
// 判别力有两处：
//  1. 末尾的 "/" 与 "///" 两例专盯本次刻意的行为变更 —— 旧实现先判空、后去斜杠，
//     输入 "/" 会返回 ("", nil)，客户端拿到 HTTP 200 和一个空基址。把本函数改回
//     旧顺序（先 if url == "" 再 TrimURL），这两例即变红。
//  2. 每例都断言结果等于 conf.TrimURL(input)，钉住「去重后两边同源」这条不变量。
//     若有人把本函数重新展开成一份私有循环并只改一边，这里会先红。
func TestNormalizePublicAPIBaseURL(t *testing.T) {
	cases := []struct {
		name    string
		in      string
		want    string
		wantErr bool
	}{
		{"无斜杠原样返回", "http://api.example.com:8888", "http://api.example.com:8888", false},
		{"去掉单个末尾斜杠", "http://api.example.com:8888/", "http://api.example.com:8888", false},
		{"去掉多个末尾斜杠", "http://api.example.com:8888///", "http://api.example.com:8888", false},
		{"去掉首尾空白", "  http://api.example.com:8888  ", "http://api.example.com:8888", false},
		{"空白加斜杠一并去掉", " \t http://x/ \n ", "http://x", false},
		{"空串报错", "", "", true},
		{"纯空白报错", "   ", "", true},
		// 以下两例是本次刻意收紧的行为：旧实现在这里返回 ("", nil)。
		{"只有斜杠必须报错而非返回空基址", "/", "", true},
		{"只有多个斜杠同样报错", "///", "", true},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := NormalizePublicAPIBaseURL(tc.in)

			if tc.wantErr {
				if !errors.Is(err, ErrNoPublicAPIBaseURL) {
					t.Fatalf("NormalizePublicAPIBaseURL(%q) err = %v，期望 ErrNoPublicAPIBaseURL", tc.in, err)
				}
				if got != "" {
					t.Errorf("NormalizePublicAPIBaseURL(%q) = %q，报错时不该同时给出基址", tc.in, got)
				}
				// 报错的前提是「规范化后为空」；若 conf.TrimURL 认为非空，说明两边判据已分叉。
				if conf.TrimURL(tc.in) != "" {
					t.Errorf("conf.TrimURL(%q) = %q 非空，但本函数报了 ErrNoPublicAPIBaseURL，两边判据不一致", tc.in, conf.TrimURL(tc.in))
				}
				return
			}

			if err != nil {
				t.Fatalf("NormalizePublicAPIBaseURL(%q) 意外报错: %v", tc.in, err)
			}
			if got != tc.want {
				t.Errorf("NormalizePublicAPIBaseURL(%q) = %q，期望 %q", tc.in, got, tc.want)
			}
			if trimmed := conf.TrimURL(tc.in); got != trimmed {
				t.Errorf("与 conf.TrimURL 不同源：本函数(%q) = %q，conf.TrimURL = %q", tc.in, got, trimmed)
			}
		})
	}
}
