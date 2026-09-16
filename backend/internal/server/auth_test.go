package server

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

// TestJWTAuthFilterAdminPaths 钉住管理端免鉴权白名单里只有登录一条路径。
//
// 判别力：把 "/api/admin/bootstrap/account" 加回 auth.go 那个 || 条件就会失败。
// 该路径曾与 /api/admin/login 并列被放过，而 AdminBootstrapAccountReq 是空消息
// （没有任何字段能携带校验凭据），biz 层还写着 _ = in，于是空库部署上任何人 POST 一次
// 就能造出 super_admin 再登录。RPC 已删除；这条用例守的是过滤器层面 —— 即便有人把路由
// 加回来，没有 admin token 也进不去。
func TestJWTAuthFilterAdminPaths(t *testing.T) {
	cases := []struct {
		path      string
		allowAnon bool
		why       string
	}{
		{"/api/admin/login", true, "登录本身必须免鉴权，否则拿不到 token 就永远登不进去"},
		{"/api/admin/bootstrap/account", false, "已删除的免鉴权超管创建入口，不得复活"},
		{"/api/admin/achievements/bootstrap", false, "其余 bootstrap 端点一律要 admin token"},
		{"/api/admin/accounts", false, "普通管理端点"},
	}

	for _, tc := range cases {
		t.Run(tc.path, func(t *testing.T) {
			reached := false
			next := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				reached = true
				w.WriteHeader(http.StatusOK)
			})

			recorder := httptest.NewRecorder()
			jwtAuthFilter(next).ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, tc.path, nil))

			if tc.allowAnon {
				if !reached {
					t.Fatalf("%s 被拦下了（status=%d）：%s", tc.path, recorder.Code, tc.why)
				}
				return
			}
			if reached {
				t.Fatalf("%s 在没有 admin token 的情况下到达了 handler：%s", tc.path, tc.why)
			}
			if recorder.Code != http.StatusUnauthorized {
				t.Errorf("%s status = %d, want %d", tc.path, recorder.Code, http.StatusUnauthorized)
			}
		})
	}
}
