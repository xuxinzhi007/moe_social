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

// TestRequiresAuthSplitsReadAndWrite 钉住白名单按方法分表之后的判定。
//
// 判别力来自两个方向，缺一个都不够：
//   - 退回旧的"不分方法单表"实现，下面所有 want=true 的写路由用例会失败
//     （旧实现里前缀命中就一律放行，DELETE /api/images/{key} 能免认证穿过过滤器）；
//   - 过度收紧（比如把 /api/images/ 或 /api/llm/models 整条拿掉），
//     want=false 的读路由用例会失败，公开图片与终端模式的模型列表会静默 401。
func TestRequiresAuthSplitsReadAndWrite(t *testing.T) {
	cases := []struct {
		method string
		path   string
		want   bool
		why    string
	}{
		// ---- 白名单读前缀下的写方法必须恢复鉴权 ----
		{http.MethodDelete, "/api/images/a.png", true, "真机实测过的洞：被 /api/images/ 放行，原先只靠适配层自己再查一次 claims 才没出事"},
		// 当初暴露同一个洞的两条真实路由是 POST /api/llm/models/delete 与 /download，
		// 已在 #42 死接口清理中连同 proto 一起删除。这里留一条合成路径当探针：
		// requiresAuth 只看前缀与方法、不查路由表，所以 /api/llm/models 这条长前缀
		// 的写方法仍被钉住 —— 将来谁在这个前缀下加写路由，默认就是需要登录。
		{http.MethodPost, "/api/llm/models/any-write", true, "写方法落在读前缀 /api/llm/models 下，仍须鉴权"},

		// ---- 同一批前缀下的读方法必须继续公开 ----
		{http.MethodGet, "/api/images/a.png", false, "帖子与头像里的图片任何人都要能看"},
		{http.MethodGet, "/api/llm/models", false, "Flutter 非终端模式的 modelsUri()，调用方不带 bearer"},
		{http.MethodGet, "/api/llm/models/raw", false, "终端模式的 modelsUri()，靠 /api/llm/models 前缀覆盖；改成精确匹配就会静默 401"},
		{http.MethodGet, "/api/llm/config", false, "App 启动即拉，登录前也要能读"},
		{http.MethodGet, "/health", false, "探活"},
		{http.MethodGet, "/swagger/openapi.yaml", false, "文档"},

		// ---- 读前缀只对安全方法生效：写方法即使路径落在读前缀下也要鉴权 ----
		{http.MethodPost, "/api/llm/chat/raw", true, "透传对话是写方法，客户端确实带 bearer"},
		{http.MethodPost, "/api/llm/show/raw", true, "同上"},

		// ---- OAuth 回调：浏览器重定向的 GET，不可能带 Authorization ----
		{http.MethodGet, "/api/auth/feishu/callback", false, "曾经只有 wechat 在表里，飞书回调被拦成 401，整条飞书登录走不完"},
		{http.MethodGet, "/api/auth/wechat/callback", false, "与飞书对称"},

		// ---- 换取 token 之前的引导写流程必须继续公开 ----
		{http.MethodPost, "/api/user/login", false, "登录本身"},
		{http.MethodPost, "/api/user/register", false, "注册"},
		{http.MethodPost, "/api/user/check-email", false, "注册前查邮箱占用"},
		{http.MethodPost, "/api/user/temp-mail/generate", false, "临时邮箱引导"},
		{http.MethodPost, "/api/auth/feishu/login", false, "OAuth 换 token"},
		{http.MethodPost, "/api/auth/wechat/login", false, "OAuth 换 token"},
		{http.MethodPost, "/api/landing/feedback", false, "落地页反馈表单，访问者本来就没有账号"},
		// 已知越权风险，按用户决定本轮不处理（任务 #47）。
		// 这条 want=false 是"保持现状"的钉子：将来真要修，改这一行会提醒你同步改文档。
		{http.MethodPost, "/api/user/reset-password", false, "#47 暂不处理，维持原样放行"},

		// ---- 写前缀不该顺带公开同路径的读方法 ----
		{http.MethodGet, "/api/user/login", true, "写前缀只对写方法放行；GET /api/user/login 不是任何客户端在用的路由"},

		// ---- 已删除的死条目：路由本来就不存在，恢复鉴权不影响任何调用方 ----
		{http.MethodGet, "/api/platform/config", true, "全仓零路由的死条目"},
		{http.MethodGet, "/api/doc", true, "文档路由只有 /swagger*"},
		{http.MethodPost, "/api/media/upload", true, "上传实际注册在 /api/upload，/api/media/ 是死条目"},
		{http.MethodGet, "/api/llm/show-raw", true, "真实路径是 /api/llm/show/raw，-raw 是死条目"},

		// ---- 前缀带斜杠的边界：GET /api/images（列表）不匹配 /api/images/ ----
		{http.MethodGet, "/api/images", true, "列表接口需要登录，只有 /api/images/{key} 取图才公开"},

		// ---- 其余一切都要鉴权 ----
		{http.MethodGet, "/api/companion/timeline", true, "登录后的业务读"},
		{http.MethodPost, "/api/posts", true, "登录后的业务写"},
		{http.MethodGet, "/ws/chat", true, "WebSocket 走 ?token= 兜底，但仍要过鉴权"},
	}

	for _, tc := range cases {
		t.Run(tc.method+" "+tc.path, func(t *testing.T) {
			got := requiresAuth(httptest.NewRequest(tc.method, tc.path, nil))
			if got != tc.want {
				t.Fatalf("requiresAuth(%s %s) = %v, want %v —— %s", tc.method, tc.path, got, tc.want, tc.why)
			}
		})
	}
}

// TestPublicPrefixListsDisjoint 守住拆分白名单的结构不变量。
//
// 同一个前缀若同时出现在读表和写表里，写方法就会重新被放行 ——
// 这正是拆分要消灭的那个洞。谁把 /api/images/ 或 /api/llm/models 复制进写表，这里就会红。
func TestPublicPrefixListsDisjoint(t *testing.T) {
	seen := make(map[string]string, len(publicReadPrefixes)+len(publicWritePrefixes))
	for _, p := range publicReadPrefixes {
		seen[p] = "publicReadPrefixes"
	}
	for _, p := range publicWritePrefixes {
		if where, dup := seen[p]; dup {
			t.Errorf("%q 同时在 %s 与 publicWritePrefixes 里：写方法会被重新放行，等于把越权洞又打开", p, where)
		}
	}
	if len(publicReadPrefixes) == 0 || len(publicWritePrefixes) == 0 {
		t.Fatal("白名单表为空，这个测试是空转的")
	}
}

// TestJWTAuthFilterWhitelistSplits 在过滤器层面复验：公开写路由无 token 也能抵达 handler，
// 而原先被前缀放行的写洞现在被拦在过滤器这一层（401，且是过滤器的措辞，不是适配层的）。
func TestJWTAuthFilterWhitelistSplits(t *testing.T) {
	cases := []struct {
		method    string
		path      string
		allowAnon bool
	}{
		{http.MethodPost, "/api/user/login", true},
		{http.MethodPost, "/api/landing/feedback", true},
		{http.MethodGet, "/api/images/a.png", true},
		{http.MethodGet, "/api/auth/feishu/callback", true},
		// 原用例是 POST /api/llm/models/delete 与 /download 两条真实路由，已在 #42
		// 死接口清理中删除。过滤器同样只按前缀+方法判定、不查路由表，所以合成路径
		// 照样钉住"/api/llm/models 这条读前缀不放行写方法"。
		{http.MethodPost, "/api/llm/models/any-write", false},
		{http.MethodDelete, "/api/images/a.png", false},
	}

	for _, tc := range cases {
		t.Run(tc.method+" "+tc.path, func(t *testing.T) {
			reached := false
			next := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				reached = true
				w.WriteHeader(http.StatusOK)
			})
			recorder := httptest.NewRecorder()
			jwtAuthFilter(next).ServeHTTP(recorder, httptest.NewRequest(tc.method, tc.path, nil))

			if tc.allowAnon {
				if !reached {
					t.Fatalf("%s %s 无 token 被拦下（status=%d），公开入口被过度收紧了", tc.method, tc.path, recorder.Code)
				}
				return
			}
			if reached {
				t.Fatalf("%s %s 无 token 竟抵达了 handler，白名单仍在放行写方法", tc.method, tc.path)
			}
			if recorder.Code != http.StatusUnauthorized {
				t.Errorf("%s %s status = %d, want %d", tc.method, tc.path, recorder.Code, http.StatusUnauthorized)
			}
		})
	}
}
