package server

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	userv1 "backend/api/user/v1"
	"backend/internal/oauthflow"
	"backend/internal/oauthtest"
	userhttp "backend/internal/server/protohttp/user"
	"backend/internal/server/transport"
	userapp "backend/internal/service/user"
	"backend/model"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

// #50 的路由级验收：真实 Kratos HTTP 服务 + 生产用的编码器与路由注册，
// 假供应商 + sqlite 内存账号库。函数级链路见 internal/biz/user/oauth_flow_test.go。
//
// 这一层专门盯三件只有真实路由才能暴露的事：
//  1. GET 授权端点的查询串绑定形式（return_url / code_challenge 到底认哪种命名）——
//     Flutter 客户端必须按实测结果传参，猜错就是静默的空值。
//  2. 失败是否走统一错误信封（success:false），而不是 200 里套一个错误。
//  3. 供应商回调经真实路由后，302 的 Location 是否只带 oauth_ticket / oauth_state。

func newOAuthHTTPServer(t *testing.T) string {
	t.Helper()

	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Skip("sqlite in-memory test requires CGO")
	}
	if err := db.AutoMigrate(&model.User{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	srv := khttp.NewServer(
		khttp.ResponseEncoder(EnvelopeResponseEncoder),
		khttp.ErrorEncoder(EnvelopeErrorEncoder),
	)
	// 与生产 http_proto.go 完全一致的注册方式；app 内部用的就是 oauthflow.Default()。
	userv1.RegisterUserServiceHTTPServer(srv, userhttp.New(userapp.New(db)))
	transport.RegisterOAuth(srv.Route("/"))

	httpServer := httptest.NewServer(srv)
	t.Cleanup(httpServer.Close)
	return httpServer.URL
}

// envelope 是统一响应信封。
type envelope struct {
	Code    float64        `json:"code"`
	Success bool           `json:"success"`
	Message string         `json:"message"`
	Reason  string         `json:"reason"`
	Data    map[string]any `json:"data"`
}

func doGetEnvelope(t *testing.T, rawURL string) (int, envelope) {
	t.Helper()
	resp, err := http.Get(rawURL)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	var out envelope
	if err := json.Unmarshal(body, &out); err != nil {
		t.Fatalf("decode %s: %v (body=%s)", rawURL, err, body)
	}
	return resp.StatusCode, out
}

func doPostEnvelope(t *testing.T, rawURL, payload string) (int, envelope) {
	t.Helper()
	resp, err := http.Post(rawURL, "application/json", strings.NewReader(payload))
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	var out envelope
	if err := json.Unmarshal(body, &out); err != nil {
		t.Fatalf("decode %s: %v (body=%s)", rawURL, err, body)
	}
	return resp.StatusCode, out
}

// TestFeishuAuthorizeURLQueryBinding 实测 GET 授权端点认哪种查询串命名。
//
// Kratos 的 BindQuery 走 form 编解码，对 proto 消息同时接受原始字段名（snake_case）
// 和 JSON 名（lowerCamelCase）。这条用例把两种都钉住：客户端传哪一种都不会静默拿到
// 空 return_url —— 空值会被白名单校验挡下，表现为一次莫名的登录失败，极难排查。
func TestFeishuAuthorizeURLQueryBinding(t *testing.T) {
	oauthtest.LoadConfig(t)
	base := newOAuthHTTPServer(t)

	cases := []struct {
		name  string
		query string
	}{
		{"snake_case", "return_url=" + url.QueryEscape(oauthtest.ListedReturnURL) + "&code_challenge=" + oauthtest.Challenge},
		{"lowerCamelCase", "returnUrl=" + url.QueryEscape(oauthtest.ListedReturnURL) + "&codeChallenge=" + oauthtest.Challenge},
	}
	for _, tc := range cases {
		status, env := doGetEnvelope(t, base+"/api/auth/feishu/authorize-url?"+tc.query)
		if status != http.StatusOK || !env.Success {
			t.Fatalf("%s: status=%d env=%+v", tc.name, status, env)
		}
		state, _ := env.Data["state"].(string)
		authorizeURL, _ := env.Data["authorize_url"].(string)
		if state == "" {
			t.Fatalf("%s: 未拿到服务端 state，data=%v", tc.name, env.Data)
		}
		if authorizeURL == "" {
			t.Fatalf("%s: 未拿到 authorize_url，data=%v", tc.name, env.Data)
		}
		if !strings.Contains(authorizeURL, "state="+state) {
			t.Fatalf("%s: 授权链接与服务端 state 不一致: %s", tc.name, authorizeURL)
		}
	}

	// 反证：完全不传 return_url 时必须失败，不能悄悄放行到某个默认地址。
	status, env := doGetEnvelope(t, base+"/api/auth/feishu/authorize-url?code_challenge="+oauthtest.Challenge)
	if status == http.StatusOK && env.Success {
		t.Fatalf("缺 return_url 不应成功: %+v", env)
	}
	if env.Success {
		t.Fatalf("失败响应不得声称 success:true: %+v", env)
	}
}

func TestFeishuAuthorizeURLRejectsEvilReturnURL(t *testing.T) {
	oauthtest.LoadConfig(t)
	base := newOAuthHTTPServer(t)

	status, env := doGetEnvelope(t, base+"/api/auth/feishu/authorize-url?return_url="+
		url.QueryEscape(oauthtest.EvilReturnURL)+"&code_challenge="+oauthtest.Challenge)
	if env.Success {
		t.Fatalf("攻击者回跳地址必须被拒绝: status=%d env=%+v", status, env)
	}
	if _, hasData := env.Data["authorize_url"]; hasData {
		t.Fatalf("失败响应不得夹带授权链接: %+v", env)
	}
	if env.Message == "" {
		t.Fatalf("失败响应必须给出面向用户的原因: %+v", env)
	}
}

// TestFeishuEndToEndOverHTTP 用真实路由走完整条链路：
// 授权 → 供应商回调（302）→ 登录（拿到 token）→ 重放（失败）。
func TestFeishuEndToEndOverHTTP(t *testing.T) {
	oauthtest.LoadConfig(t)
	fs := oauthtest.NewFeishu(t)
	base := newOAuthHTTPServer(t)

	// 1) 授权
	_, env := doGetEnvelope(t, base+"/api/auth/feishu/authorize-url?return_url="+
		url.QueryEscape(oauthtest.ListedReturnURL)+"&code_challenge="+oauthtest.Challenge)
	if !env.Success {
		t.Fatalf("授权失败: %+v", env)
	}
	state, _ := env.Data["state"].(string)
	if state == "" {
		t.Fatalf("未拿到 state: %+v", env)
	}

	// 2) 供应商回调：不跟随重定向，检查 Location。
	client := &http.Client{CheckRedirect: func(*http.Request, []*http.Request) error {
		return http.ErrUseLastResponse
	}}
	callbackURL := base + "/api/auth/feishu/callback?code=" + url.QueryEscape(oauthtest.FeishuCode) +
		"&state=" + url.QueryEscape(state)
	cbResp, err := client.Get(callbackURL)
	if err != nil {
		t.Fatal(err)
	}
	cbBody, _ := io.ReadAll(cbResp.Body)
	cbResp.Body.Close()

	if cbResp.StatusCode != http.StatusFound {
		t.Fatalf("回调应 302，got %d body=%s", cbResp.StatusCode, cbBody)
	}
	loc := cbResp.Header.Get("Location")
	parsed, err := url.Parse(loc)
	if err != nil {
		t.Fatalf("parse Location %q: %v", loc, err)
	}
	if parsed.Host != "app.example.com" {
		t.Fatalf("只能回跳到白名单主机，got %q (Location=%s)", parsed.Host, loc)
	}
	ticket := parsed.Query().Get("oauth_ticket")
	if ticket == "" {
		t.Fatalf("回跳未带 oauth_ticket: %s", loc)
	}
	if strings.Contains(loc, oauthtest.FeishuCode) {
		t.Fatalf("回跳地址不得携带授权码: %s", loc)
	}
	if got := parsed.Query().Get("code"); got != "" {
		t.Fatalf("回跳地址出现了 code 参数: %s", loc)
	}
	if got := cbResp.Header.Get("Cache-Control"); got != "no-store" {
		t.Errorf("Cache-Control = %q, want no-store", got)
	}
	if got := cbResp.Header.Get("Referrer-Policy"); got != "no-referrer" {
		t.Errorf("Referrer-Policy = %q, want no-referrer", got)
	}

	// 3) 登录
	status, loginEnv := doPostEnvelope(t, base+"/api/auth/feishu/login",
		`{"ticket":"`+ticket+`","code_verifier":"`+oauthtest.Verifier+`"}`)
	if status != http.StatusOK || !loginEnv.Success {
		t.Fatalf("登录应成功: status=%d env=%+v", status, loginEnv)
	}
	if tok, _ := loginEnv.Data["token"].(string); tok == "" {
		t.Fatalf("登录成功必须下发 token: %+v", loginEnv.Data)
	}
	if codes := fs.SeenCodes(); len(codes) != 1 || codes[0] != oauthtest.FeishuCode {
		t.Fatalf("假飞书应恰好收到一次授权码，got %v", codes)
	}

	// 4) 同一张 ticket 重放：必须是失败信封，且不得再触达供应商。
	replayStatus, replayEnv := doPostEnvelope(t, base+"/api/auth/feishu/login",
		`{"ticket":"`+ticket+`","code_verifier":"`+oauthtest.Verifier+`"}`)
	if replayEnv.Success {
		t.Fatalf("ticket 重放不得成功: status=%d env=%+v", replayStatus, replayEnv)
	}
	if _, hasToken := replayEnv.Data["token"]; hasToken {
		t.Fatalf("重放响应不得夹带 token: %+v", replayEnv)
	}
	if codes := fs.SeenCodes(); len(codes) != 1 {
		t.Fatalf("重放不得再次触达供应商，got %v", codes)
	}
}

// TestFeishuLoginRejectsLegacyCodeOverHTTP 钉住旧的 code-only 通路在真实路由上已关闭。
func TestFeishuLoginRejectsLegacyCodeOverHTTP(t *testing.T) {
	oauthtest.LoadConfig(t)
	fs := oauthtest.NewFeishu(t)
	base := newOAuthHTTPServer(t)

	status, env := doPostEnvelope(t, base+"/api/auth/feishu/login",
		`{"code":"`+oauthtest.FeishuCode+`"}`)
	if env.Success {
		t.Fatalf("旧的 code-only 登录必须失败: status=%d env=%+v", status, env)
	}
	if _, hasToken := env.Data["token"]; hasToken {
		t.Fatalf("失败响应不得夹带 token: %+v", env)
	}
	if codes := fs.SeenCodes(); len(codes) != 0 {
		t.Fatalf("拒绝路径不得触达供应商，got %v", codes)
	}
}

// TestFeishuCallbackOverHTTPRejectsBadState 覆盖真实路由上的取消 / 篡改 / 重放。
func TestFeishuCallbackOverHTTPRejectsBadState(t *testing.T) {
	oauthtest.LoadConfig(t)
	base := newOAuthHTTPServer(t)

	_, env := doGetEnvelope(t, base+"/api/auth/feishu/authorize-url?return_url="+
		url.QueryEscape(oauthtest.ListedReturnURL)+"&code_challenge="+oauthtest.Challenge)
	state, _ := env.Data["state"].(string)
	if state == "" {
		t.Fatalf("未拿到 state: %+v", env)
	}

	client := &http.Client{CheckRedirect: func(*http.Request, []*http.Request) error {
		return http.ErrUseLastResponse
	}}
	cases := []struct {
		name  string
		query string
	}{
		{"用户取消", "?error=access_denied&state=" + url.QueryEscape(state)},
		{"state 被篡改", "?code=" + oauthtest.FeishuCode + "&state=" + url.QueryEscape(state[:len(state)-1]+"A")},
		{"凭空捏造 state", "?code=" + oauthtest.FeishuCode + "&state=moe_social"},
		{"拿回跳地址当 state（旧协议）", "?code=" + oauthtest.FeishuCode + "&state=" + url.QueryEscape(oauthtest.EvilReturnURL)},
	}
	for _, tc := range cases {
		resp, err := client.Get(base + "/api/auth/feishu/callback" + tc.query)
		if err != nil {
			t.Fatal(err)
		}
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		if resp.StatusCode == http.StatusFound {
			t.Errorf("%s: 不得 302 回跳，Location=%q", tc.name, resp.Header.Get("Location"))
		}
		if loc := resp.Header.Get("Location"); loc != "" {
			t.Errorf("%s: 不得设置 Location，got %q", tc.name, loc)
		}
		if strings.Contains(string(body), oauthtest.FeishuCode) {
			t.Errorf("%s: 失败页不得显示授权码: %s", tc.name, body)
		}
	}

	// 正常 state 用掉一次之后，第二次必须失败（浏览器预取 / 刷新 / 攻击者重放）。
	okResp, err := client.Get(base + "/api/auth/feishu/callback?code=" + url.QueryEscape(oauthtest.FeishuCode) +
		"&state=" + url.QueryEscape(state))
	if err != nil {
		t.Fatal(err)
	}
	okBody, _ := io.ReadAll(okResp.Body)
	okResp.Body.Close()
	if okResp.StatusCode != http.StatusFound {
		t.Fatalf("首次回调应 302，got %d body=%s", okResp.StatusCode, okBody)
	}
	replayResp, err := client.Get(base + "/api/auth/feishu/callback?code=" + url.QueryEscape(oauthtest.FeishuCode) +
		"&state=" + url.QueryEscape(state))
	if err != nil {
		t.Fatal(err)
	}
	replayBody, _ := io.ReadAll(replayResp.Body)
	replayResp.Body.Close()
	if replayResp.StatusCode == http.StatusFound {
		t.Fatalf("state 重放不得再次 302，Location=%q", replayResp.Header.Get("Location"))
	}
	if strings.Contains(string(replayBody), oauthtest.FeishuCode) {
		t.Fatalf("重放失败页不得显示授权码: %s", replayBody)
	}
}

// TestWechatAppFlowOverHTTP 覆盖原生 SDK flow：授权端点只发 state（不下发授权页地址），
// 登录用 state + SDK 的 code + verifier。
func TestWechatAppFlowOverHTTP(t *testing.T) {
	oauthtest.LoadConfig(t)
	wx := oauthtest.NewWechat(t)
	base := newOAuthHTTPServer(t)

	status, env := doGetEnvelope(t, base+"/api/auth/wechat/authorize-url?flow=app&code_challenge="+oauthtest.Challenge)
	if status != http.StatusOK || !env.Success {
		t.Fatalf("app flow 授权应成功: status=%d env=%+v", status, env)
	}
	state, _ := env.Data["state"].(string)
	if state == "" {
		t.Fatalf("app flow 必须拿到服务端 state: %+v", env.Data)
	}
	if authURL, _ := env.Data["authorize_url"].(string); authURL != "" {
		t.Fatalf("app flow 不应下发授权页地址，got %q", authURL)
	}

	loginStatus, loginEnv := doPostEnvelope(t, base+"/api/auth/wechat/login",
		`{"code":"`+oauthtest.WechatCode+`","state":"`+state+`","code_verifier":"`+oauthtest.Verifier+`"}`)
	if loginStatus != http.StatusOK || !loginEnv.Success {
		t.Fatalf("app flow 登录应成功: status=%d env=%+v", loginStatus, loginEnv)
	}
	if tok, _ := loginEnv.Data["token"].(string); tok == "" {
		t.Fatalf("应下发 token: %+v", loginEnv.Data)
	}
	if _, appIDs := wx.Seen(); len(appIDs) != 1 || appIDs[0] != oauthtest.WechatAppAppID {
		t.Fatalf("app flow 应使用 wechat.app 凭证，got %v", appIDs)
	}

	// 同一 state 二次提交必须失败。
	_, replay := doPostEnvelope(t, base+"/api/auth/wechat/login",
		`{"code":"`+oauthtest.WechatCode+`","state":"`+state+`","code_verifier":"`+oauthtest.Verifier+`"}`)
	if replay.Success {
		t.Fatalf("state 重放不得成功: %+v", replay)
	}
}

// TestWechatBrowserFlowOverHTTP 覆盖 website flow 的完整 HTTP 链路。
func TestWechatBrowserFlowOverHTTP(t *testing.T) {
	oauthtest.LoadConfig(t)
	wx := oauthtest.NewWechat(t)
	base := newOAuthHTTPServer(t)

	_, env := doGetEnvelope(t, base+"/api/auth/wechat/authorize-url?flow=website&return_url="+
		url.QueryEscape(oauthtest.ListedReturnURL)+"&code_challenge="+oauthtest.Challenge)
	if !env.Success {
		t.Fatalf("website flow 授权应成功: %+v", env)
	}
	state, _ := env.Data["state"].(string)
	authorizeURL, _ := env.Data["authorize_url"].(string)
	if state == "" || !strings.Contains(authorizeURL, "/connect/qrconnect") {
		t.Fatalf("website flow 应下发扫码登录地址: state=%q url=%q", state, authorizeURL)
	}

	client := &http.Client{CheckRedirect: func(*http.Request, []*http.Request) error {
		return http.ErrUseLastResponse
	}}
	resp, err := client.Get(base + "/api/auth/wechat/callback?code=" + url.QueryEscape(oauthtest.WechatCode) +
		"&state=" + url.QueryEscape(state))
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusFound {
		t.Fatalf("回调应 302，got %d body=%s", resp.StatusCode, body)
	}
	loc, err := url.Parse(resp.Header.Get("Location"))
	if err != nil {
		t.Fatal(err)
	}
	if loc.Host != "app.example.com" {
		t.Fatalf("只能回跳白名单主机，got %q", loc.Host)
	}
	if strings.Contains(resp.Header.Get("Location"), oauthtest.WechatCode) {
		t.Fatalf("回跳地址不得携带授权码: %s", resp.Header.Get("Location"))
	}

	ticket := loc.Query().Get("oauth_ticket")
	loginStatus, loginEnv := doPostEnvelope(t, base+"/api/auth/wechat/login",
		`{"ticket":"`+ticket+`","code_verifier":"`+oauthtest.Verifier+`"}`)
	if loginStatus != http.StatusOK || !loginEnv.Success {
		t.Fatalf("website flow 登录应成功: status=%d env=%+v", loginStatus, loginEnv)
	}
	if _, appIDs := wx.Seen(); len(appIDs) != 1 || appIDs[0] != oauthtest.WechatWebAppID {
		t.Fatalf("website flow 应使用 wechat.website 凭证，got %v", appIDs)
	}
}

// TestOAuthStoreIsSharedAcrossRequests 三次独立 HTTP 请求必须命中同一份事务存储，
// 否则授权端点签发的 state 在回调里根本查不到（曾按请求 new Store 就会这样）。
func TestOAuthStoreIsSharedAcrossRequests(t *testing.T) {
	oauthtest.LoadConfig(t)
	base := newOAuthHTTPServer(t)

	first := oauthflow.Default()
	second := oauthflow.Default()
	if first != second {
		t.Fatal("oauthflow.Default() 必须返回同一个实例")
	}

	_, env := doGetEnvelope(t, base+"/api/auth/feishu/authorize-url?return_url="+
		url.QueryEscape(oauthtest.ListedReturnURL)+"&code_challenge="+oauthtest.Challenge)
	state, _ := env.Data["state"].(string)
	if state == "" {
		t.Fatalf("未拿到 state: %+v", env)
	}
	if auths, _ := first.PendingCounts(); auths < 1 {
		t.Fatalf("授权端点应把事务写进共享存储，pending=%d", auths)
	}
}
