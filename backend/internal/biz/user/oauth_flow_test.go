package userbiz_test

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"testing"
	"time"

	userv1 "backend/api/user/v1"
	userbiz "backend/internal/biz/user"
	"backend/internal/oauthflow"
	"backend/internal/oauthtest"
)

// #50 的服务端验收（函数级）：假供应商 + 真实调用链，覆盖两家成功链路与全部失败分支。
//
// 这些用例刻意不启动普通后端、不连 MySQL、不碰真实飞书/微信：DB 是 sqlite 内存库，
// 供应商是 httptest 起的本地假服务端（出网目标被改写到 127.0.0.1）。
// 路由级（真实 Kratos HTTP + 查询串绑定 + 错误信封）见 internal/server/oauth_http_test.go。
// 真实供应商授权与原生 SDK 行为属于设备/人工依赖，另行记录，不由单测代替。

// ---------------------------------------------------------------- 公共步骤

// runFeishuBrowserAuth 走完「发起授权 → 供应商回调」，返回 state 与回调 302 里的 ticket。
func runFeishuBrowserAuth(t *testing.T, ctx context.Context, txs *oauthflow.Store, returnURL string) (state, ticket string, rec *httptest.ResponseRecorder) {
	t.Helper()
	authResp, err := userbiz.FeishuAuthorizeURL(ctx, txs, &userv1.FeishuAuthorizeURLReq{
		ReturnUrl:     returnURL,
		CodeChallenge: oauthtest.Challenge,
	})
	if err != nil {
		t.Fatalf("FeishuAuthorizeURL: %v", err)
	}
	rec = httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/auth/feishu/callback", nil)
	userbiz.HandleFeishuOAuthCallback(rec, req, userbiz.FeishuOAuthCallbackInput{
		Code: oauthtest.FeishuCode, State: authResp.State,
	})
	if rec.Code != http.StatusFound {
		t.Fatalf("回调应 302，got %d body=%s", rec.Code, rec.Body.String())
	}
	loc, err := url.Parse(rec.Header().Get("Location"))
	if err != nil {
		t.Fatalf("parse Location: %v", err)
	}
	return authResp.State, loc.Query().Get("oauth_ticket"), rec
}

func runWechatBrowserAuth(t *testing.T, ctx context.Context, txs *oauthflow.Store, flow, returnURL string) (state, ticket string, rec *httptest.ResponseRecorder) {
	t.Helper()
	authResp, err := userbiz.WechatAuthorizeURL(ctx, txs, &userv1.WechatAuthorizeURLReq{
		Flow:          flow,
		ReturnUrl:     returnURL,
		CodeChallenge: oauthtest.Challenge,
	})
	if err != nil {
		t.Fatalf("WechatAuthorizeURL: %v", err)
	}
	rec = httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/auth/wechat/callback", nil)
	userbiz.HandleWechatOAuthCallback(rec, req, userbiz.WechatOAuthCallbackInput{
		Code: oauthtest.WechatCode, State: authResp.State,
	})
	if rec.Code != http.StatusFound {
		t.Fatalf("回调应 302，got %d body=%s", rec.Code, rec.Body.String())
	}
	loc, err := url.Parse(rec.Header().Get("Location"))
	if err != nil {
		t.Fatalf("parse Location: %v", err)
	}
	return authResp.State, loc.Query().Get("oauth_ticket"), rec
}

// ---------------------------------------------------------------- 飞书

func TestFeishuAuthorizeURLIgnoresLegacyStateField(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)

	resp, err := userbiz.FeishuAuthorizeURL(ctx, oauthflow.Default(), &userv1.FeishuAuthorizeURLReq{
		// 旧协议把回跳地址塞进 state，这正是开放重定向的入口；新实现必须完全忽略它。
		State:         oauthtest.EvilReturnURL,
		ReturnUrl:     oauthtest.ListedReturnURL,
		CodeChallenge: oauthtest.Challenge,
	})
	if err != nil {
		t.Fatalf("FeishuAuthorizeURL: %v", err)
	}
	if resp.State == "" {
		t.Fatal("服务端必须签发 state")
	}
	if resp.State == oauthtest.EvilReturnURL {
		t.Fatal("state 不得回显请求里的值（旧实现直接把它当回跳地址）")
	}
	if resp.State == "moe_social" {
		t.Fatal("固定兜底 state 等于关掉 CSRF 防护")
	}
	if strings.Contains(resp.AuthorizeUrl, "evil.example.com") {
		t.Fatalf("攻击者站点不得出现在授权链接里: %s", resp.AuthorizeUrl)
	}

	u, err := url.Parse(resp.AuthorizeUrl)
	if err != nil {
		t.Fatalf("parse authorize_url: %v", err)
	}
	q := u.Query()
	if q.Get("state") != resp.State {
		t.Fatalf("授权链接里的 state 应与服务端事务一致: %q vs %q", q.Get("state"), resp.State)
	}
	if got := q.Get("redirect_uri"); got != oauthtest.FeishuCallbackURI {
		t.Fatalf("redirect_uri = %q, want %q", got, oauthtest.FeishuCallbackURI)
	}
	if q.Get("app_id") != "cli_oauth_test" {
		t.Fatalf("app_id = %q", q.Get("app_id"))
	}
}

func TestFeishuAuthorizeURLRejectsUnlistedReturnURL(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	txs := oauthflow.Default()

	rejected := []struct {
		name string
		raw  string
	}{
		{"空回跳", ""},
		{"攻击者站点", oauthtest.EvilReturnURL},
		{"白名单当查询参数", "https://evil.example.com/x?next=" + url.QueryEscape(oauthtest.ListedReturnURL)},
		{"同前缀不同主机", oauthtest.ListedReturnURL + ".evil.example.com"},
		{"userinfo 伪装", "https://app.example.com@evil.example.com/login"},
		{"javascript 协议", "javascript:alert(1)"},
		{"多一段路径", oauthtest.ListedReturnURL + "/../evil"},
		{"带查询串", oauthtest.ListedReturnURL + "?x=1"},
	}
	for _, tc := range rejected {
		_, err := userbiz.FeishuAuthorizeURL(ctx, txs, &userv1.FeishuAuthorizeURLReq{
			ReturnUrl:     tc.raw,
			CodeChallenge: oauthtest.Challenge,
		})
		if !errors.Is(err, userbiz.ErrInvalidArgument) {
			t.Errorf("%s(%q): 应拒绝并回 ErrInvalidArgument，got %v", tc.name, tc.raw, err)
		}
	}
}

func TestFeishuBrowserFlowSuccessAndReplay(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	fs := oauthtest.NewFeishu(t)
	store := oauthtest.OpenStore(t)
	txs := oauthflow.Default()

	state, ticket, rec := runFeishuBrowserAuth(t, ctx, txs, oauthtest.ListedReturnURL)
	if ticket == "" {
		t.Fatalf("回调未签发 ticket，Location=%q", rec.Header().Get("Location"))
	}

	loc := rec.Header().Get("Location")
	parsed, err := url.Parse(loc)
	if err != nil {
		t.Fatal(err)
	}
	if parsed.Host != "app.example.com" {
		t.Fatalf("只能 302 回白名单主机，got %q", parsed.Host)
	}
	if strings.Contains(loc, oauthtest.FeishuCode) {
		t.Fatalf("回跳地址不得携带授权码: %s", loc)
	}
	if got := parsed.Query().Get("oauth_state"); got != state {
		t.Fatalf("oauth_state = %q, want %q", got, state)
	}
	for header, want := range map[string]string{
		"Cache-Control":   "no-store",
		"Pragma":          "no-cache",
		"Referrer-Policy": "no-referrer",
	} {
		if got := rec.Header().Get(header); got != want {
			t.Errorf("%s = %q, want %q", header, got, want)
		}
	}

	// 回调用同一个 state 再来一次：state 取出即作废，第二次必须失败且不发新票。
	rec2 := httptest.NewRecorder()
	req2 := httptest.NewRequest(http.MethodGet, "/api/auth/feishu/callback", nil)
	userbiz.HandleFeishuOAuthCallback(rec2, req2, userbiz.FeishuOAuthCallbackInput{
		Code: oauthtest.FeishuCode, State: state,
	})
	if rec2.Code != http.StatusBadRequest {
		t.Fatalf("state 重放应 400，got %d", rec2.Code)
	}
	if rec2.Header().Get("Location") != "" {
		t.Fatal("重放不得再签发回跳")
	}
	if strings.Contains(rec2.Body.String(), oauthtest.FeishuCode) {
		t.Fatalf("失败页不得显示授权码: %s", rec2.Body.String())
	}

	resp, err := userbiz.FeishuLogin(ctx, store, txs, &userv1.FeishuLoginReq{
		Ticket:       ticket,
		CodeVerifier: oauthtest.Verifier,
	})
	if err != nil {
		t.Fatalf("首次登录应成功: %v", err)
	}
	if resp.Token == "" {
		t.Fatal("登录成功必须下发 token")
	}
	if !resp.IsNewUser {
		t.Fatal("首次登录应标记为新用户")
	}
	if !resp.User.GetFeishuBound() {
		t.Fatal("登录成功后账号应标记为已绑定飞书")
	}
	if got := resp.User.GetFeishuName(); got != oauthtest.FeishuName {
		t.Fatalf("假飞书返回的资料未落库: feishu_name = %q", got)
	}
	if codes := fs.SeenCodes(); len(codes) != 1 || codes[0] != oauthtest.FeishuCode {
		t.Fatalf("假飞书应恰好收到一次原始授权码，got %v", codes)
	}

	// ticket 重放：必须失败，且不得再次触达供应商。
	if _, err := userbiz.FeishuLogin(ctx, store, txs, &userv1.FeishuLoginReq{
		Ticket: ticket, CodeVerifier: oauthtest.Verifier,
	}); !errors.Is(err, userbiz.ErrUnauthorized) {
		t.Fatalf("ticket 重放应 ErrUnauthorized，got %v", err)
	}
	if codes := fs.SeenCodes(); len(codes) != 1 {
		t.Fatalf("重放不得再次调用供应商，got %v", codes)
	}

	// 同一个飞书账号再走一次完整流程：应识别为老用户而不是重复建号。
	_, ticket2, _ := runFeishuBrowserAuth(t, ctx, txs, oauthtest.ListedReturnURL)
	again, err := userbiz.FeishuLogin(ctx, store, txs, &userv1.FeishuLoginReq{
		Ticket: ticket2, CodeVerifier: oauthtest.Verifier,
	})
	if err != nil {
		t.Fatalf("二次登录: %v", err)
	}
	if again.IsNewUser {
		t.Fatal("同一 open_id 不应再次判定为新用户")
	}
	if again.User.GetId() != resp.User.GetId() {
		t.Fatalf("应命中同一账号: %q vs %q", again.User.GetId(), resp.User.GetId())
	}
}

func TestFeishuLoginRejectsWrongVerifierAndBurnsTicket(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	fs := oauthtest.NewFeishu(t)
	store := oauthtest.OpenStore(t)
	txs := oauthflow.Default()

	_, ticket, _ := runFeishuBrowserAuth(t, ctx, txs, oauthtest.ListedReturnURL)

	_, err := userbiz.FeishuLogin(ctx, store, txs, &userv1.FeishuLoginReq{
		Ticket: ticket, CodeVerifier: oauthtest.WrongVerifier,
	})
	if !errors.Is(err, userbiz.ErrInvalidArgument) {
		t.Fatalf("错误 verifier 应 ErrInvalidArgument，got %v", err)
	}
	if codes := fs.SeenCodes(); len(codes) != 0 {
		t.Fatalf("verifier 不对时不得拿授权码去换用户资料，got %v", codes)
	}
	// 关键：verifier 试错失败后票据已作废，拿正确 verifier 再试也不行。
	// 否则攻击者可以对同一张票暴力枚举 verifier。
	if _, err := userbiz.FeishuLogin(ctx, store, txs, &userv1.FeishuLoginReq{
		Ticket: ticket, CodeVerifier: oauthtest.Verifier,
	}); !errors.Is(err, userbiz.ErrUnauthorized) {
		t.Fatalf("verifier 试错后票据应已作废，got %v", err)
	}
	if codes := fs.SeenCodes(); len(codes) != 0 {
		t.Fatalf("全程不得触达供应商，got %v", codes)
	}
}

func TestFeishuLoginFailsWhenProviderExchangeFails(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	fs := oauthtest.NewFeishu(t)
	fs.FailExchange = true
	store := oauthtest.OpenStore(t)
	txs := oauthflow.Default()

	_, ticket, _ := runFeishuBrowserAuth(t, ctx, txs, oauthtest.ListedReturnURL)
	_, err := userbiz.FeishuLogin(ctx, store, txs, &userv1.FeishuLoginReq{
		Ticket: ticket, CodeVerifier: oauthtest.Verifier,
	})
	if !errors.Is(err, userbiz.ErrUnauthorized) {
		t.Fatalf("供应商拒绝授权码时必须失败，got %v", err)
	}
	if !strings.Contains(err.Error(), "飞书授权失败") {
		t.Fatalf("应给出面向用户的中文原因，got %q", err.Error())
	}
}

func TestFeishuLoginRejectsLegacyCodeOnly(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	fs := oauthtest.NewFeishu(t)
	store := oauthtest.OpenStore(t)
	txs := oauthflow.Default()

	_, err := userbiz.FeishuLogin(ctx, store, txs, &userv1.FeishuLoginReq{
		Code: oauthtest.FeishuCode,
	})
	if !errors.Is(err, userbiz.ErrInvalidArgument) {
		t.Fatalf("旧的 code-only 通路必须关闭，got %v", err)
	}
	if codes := fs.SeenCodes(); len(codes) != 0 {
		t.Fatalf("拒绝路径不得触达供应商，got %v", codes)
	}

	// 同时带 code 与 ticket：code 非空即拒绝，不给「顺手带上」留口子。
	_, ticket, _ := runFeishuBrowserAuth(t, ctx, txs, oauthtest.ListedReturnURL)
	if _, err := userbiz.FeishuLogin(ctx, store, txs, &userv1.FeishuLoginReq{
		Code: oauthtest.FeishuCode, Ticket: ticket, CodeVerifier: oauthtest.Verifier,
	}); !errors.Is(err, userbiz.ErrInvalidArgument) {
		t.Fatalf("code 与 ticket 并存应拒绝，got %v", err)
	}
	if codes := fs.SeenCodes(); len(codes) != 0 {
		t.Fatalf("拒绝路径不得触达供应商，got %v", codes)
	}
}

func TestFeishuLoginRejectsWechatTicket(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	store := oauthtest.OpenStore(t)
	txs := oauthflow.Default()

	_, wechatTicket, _ := runWechatBrowserAuth(t, ctx, txs, "website", oauthtest.ListedReturnURL)
	if _, err := userbiz.FeishuLogin(ctx, store, txs, &userv1.FeishuLoginReq{
		Ticket: wechatTicket, CodeVerifier: oauthtest.Verifier,
	}); !errors.Is(err, userbiz.ErrUnauthorized) {
		t.Fatalf("跨供应商票据应 ErrUnauthorized，got %v", err)
	}
}

func TestFeishuCallbackRejectsMissingTamperedAndCrossProviderState(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	txs := oauthflow.Default()

	authResp, err := userbiz.FeishuAuthorizeURL(ctx, txs, &userv1.FeishuAuthorizeURLReq{
		ReturnUrl: oauthtest.ListedReturnURL, CodeChallenge: oauthtest.Challenge,
	})
	if err != nil {
		t.Fatal(err)
	}

	cases := []struct {
		name  string
		code  string
		state string
	}{
		{"用户取消（供应商只带 error）", "", authResp.State},
		{"缺 state", oauthtest.FeishuCode, ""},
		{"state 被篡改一位", oauthtest.FeishuCode, authResp.State[:len(authResp.State)-1] + "A"},
		{"凭空捏造 state", oauthtest.FeishuCode, "moe_social"},
		{"拿回跳地址当 state（旧协议）", oauthtest.FeishuCode, oauthtest.EvilReturnURL},
	}
	for _, tc := range cases {
		rec := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/api/auth/feishu/callback", nil)
		userbiz.HandleFeishuOAuthCallback(rec, req, userbiz.FeishuOAuthCallbackInput{
			Code: tc.code, State: tc.state,
		})
		if rec.Code != http.StatusBadRequest {
			t.Errorf("%s: 应 400，got %d", tc.name, rec.Code)
		}
		if loc := rec.Header().Get("Location"); loc != "" {
			t.Errorf("%s: 不得回跳，Location=%q", tc.name, loc)
		}
		if strings.Contains(rec.Body.String(), oauthtest.FeishuCode) {
			t.Errorf("%s: 失败页不得显示授权码", tc.name)
		}
	}

	// 微信事务打到飞书回调：同样按失效处理，不解释差异（免得变成探测接口）。
	wxResp, err := userbiz.WechatAuthorizeURL(ctx, txs, &userv1.WechatAuthorizeURLReq{
		Flow: "website", ReturnUrl: oauthtest.ListedReturnURL, CodeChallenge: oauthtest.Challenge,
	})
	if err != nil {
		t.Fatal(err)
	}
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/auth/feishu/callback", nil)
	userbiz.HandleFeishuOAuthCallback(rec, req, userbiz.FeishuOAuthCallbackInput{
		Code: oauthtest.FeishuCode, State: wxResp.State,
	})
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("跨供应商回调应 400，got %d", rec.Code)
	}
	if rec.Header().Get("Location") != "" {
		t.Fatal("跨供应商回调不得回跳")
	}
	if strings.Contains(rec.Body.String(), oauthtest.FeishuCode) {
		t.Fatalf("失败页不得显示授权码: %s", rec.Body.String())
	}
}

func TestFeishuLoginDisabled(t *testing.T) {
	ctx := oauthtest.LoadConfig(t, func(yaml string) string {
		return strings.Replace(yaml,
			"feishu:\n  enabled: true", "feishu:\n  enabled: false", 1)
	})

	if _, err := userbiz.FeishuAuthorizeURL(ctx, oauthflow.Default(), &userv1.FeishuAuthorizeURLReq{
		ReturnUrl: oauthtest.ListedReturnURL, CodeChallenge: oauthtest.Challenge,
	}); !errors.Is(err, userbiz.ErrOAuthDisabled) {
		t.Fatalf("未启用飞书时应 ErrOAuthDisabled，got %v", err)
	}
	if _, err := userbiz.FeishuLogin(ctx, oauthtest.OpenStore(t), oauthflow.Default(), &userv1.FeishuLoginReq{
		Ticket: "whatever", CodeVerifier: oauthtest.Verifier,
	}); !errors.Is(err, userbiz.ErrOAuthDisabled) {
		t.Fatalf("未启用飞书时登录应 ErrOAuthDisabled，got %v", err)
	}
}

// ---------------------------------------------------------------- 微信

func TestWechatBrowserFlowSuccessAndReplay(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	wx := oauthtest.NewWechat(t)
	store := oauthtest.OpenStore(t)
	txs := oauthflow.Default()

	state, ticket, rec := runWechatBrowserAuth(t, ctx, txs, "website", oauthtest.ListedReturnURL)
	loc := rec.Header().Get("Location")
	if strings.Contains(loc, oauthtest.WechatCode) {
		t.Fatalf("回跳地址不得携带授权码: %s", loc)
	}
	if !strings.Contains(loc, "oauth_ticket=") || !strings.Contains(loc, "oauth_state="+state) {
		t.Fatalf("回跳只应带 ticket/state: %s", loc)
	}

	resp, err := userbiz.WechatLogin(ctx, store, txs, &userv1.WechatLoginReq{
		Ticket: ticket, CodeVerifier: oauthtest.Verifier,
	})
	if err != nil {
		t.Fatalf("微信浏览器 flow 登录应成功: %v", err)
	}
	if resp.Token == "" || !resp.IsNewUser {
		t.Fatalf("token=%q isNew=%v", resp.Token, resp.IsNewUser)
	}
	if !resp.User.GetWechatBound() {
		t.Fatal("登录成功后账号应标记为已绑定微信")
	}
	// website(qrconnect) flow 的 token 响应 scope 是 snsapi_login，
	// ExchangeWechatOAuthCode 据此**不**再拉 /sns/userinfo，所以昵称留空是既有生产行为。
	// 拉资料的分支由 TestWechatMpFlowFetchesProfile 覆盖。
	if got := resp.User.GetWechatNickname(); got != "" {
		t.Fatalf("snsapi_login 不应拉取资料，wechat_nickname = %q", got)
	}
	if n := wx.ProfileFetches(); n != 0 {
		t.Fatalf("snsapi_login 不应触达 /sns/userinfo，实际 %d 次", n)
	}
	codes, appIDs := wx.Seen()
	if len(codes) != 1 || codes[0] != oauthtest.WechatCode {
		t.Fatalf("假微信应恰好收到一次授权码，got %v", codes)
	}
	// flow 取自服务端事务，不是请求字段：website 事务必须用 website 凭证换取。
	if len(appIDs) != 1 || appIDs[0] != oauthtest.WechatWebAppID {
		t.Fatalf("website flow 应使用 wechat.website 凭证，got %v", appIDs)
	}

	if _, err := userbiz.WechatLogin(ctx, store, txs, &userv1.WechatLoginReq{
		Ticket: ticket, CodeVerifier: oauthtest.Verifier,
	}); !errors.Is(err, userbiz.ErrUnauthorized) {
		t.Fatalf("ticket 重放应 ErrUnauthorized，got %v", err)
	}
	if codes, _ := wx.Seen(); len(codes) != 1 {
		t.Fatalf("重放不得再次触达供应商，got %v", codes)
	}
}

func TestWechatMpFlowFetchesProfile(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	wx := oauthtest.NewWechat(t, "snsapi_userinfo")
	store := oauthtest.OpenStore(t)
	txs := oauthflow.Default()

	_, ticket, _ := runWechatBrowserAuth(t, ctx, txs, "mp", oauthtest.ListedReturnURL)
	resp, err := userbiz.WechatLogin(ctx, store, txs, &userv1.WechatLoginReq{
		Ticket: ticket, CodeVerifier: oauthtest.Verifier,
	})
	if err != nil {
		t.Fatalf("mp flow 登录应成功: %v", err)
	}
	if got := resp.User.GetWechatNickname(); got != oauthtest.WechatNickname {
		t.Fatalf("snsapi_userinfo 应拉取并落库昵称，got %q", got)
	}
	if n := wx.ProfileFetches(); n != 1 {
		t.Fatalf("/sns/userinfo 应恰好被调用一次，实际 %d 次", n)
	}
	_, appIDs := wx.Seen()
	if len(appIDs) != 1 || appIDs[0] != oauthtest.WechatMPAppID {
		t.Fatalf("mp flow 应使用 wechat.mp 凭证，got %v", appIDs)
	}
}

func TestWechatAuthorizeURLBuildsFlowSpecificLink(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	txs := oauthflow.Default()

	resp, err := userbiz.WechatAuthorizeURL(ctx, txs, &userv1.WechatAuthorizeURLReq{
		// 旧字段：曾是回跳地址，必须被完全忽略。
		State:         oauthtest.EvilReturnURL,
		Flow:          "website",
		ReturnUrl:     oauthtest.ListedReturnURL,
		CodeChallenge: oauthtest.Challenge,
	})
	if err != nil {
		t.Fatal(err)
	}
	if resp.State == "" || resp.State == oauthtest.EvilReturnURL || resp.State == "moe_social" {
		t.Fatalf("服务端必须签发随机 state，got %q", resp.State)
	}
	u, err := url.Parse(resp.AuthorizeUrl)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(u.Path, "/connect/qrconnect") {
		t.Fatalf("website flow 应走扫码登录端点，got %q", u.Path)
	}
	if got := u.Query().Get("state"); got != resp.State {
		t.Fatalf("授权链接 state = %q, want %q", got, resp.State)
	}
	if got := u.Query().Get("appid"); got != oauthtest.WechatWebAppID {
		t.Fatalf("appid = %q", got)
	}
	if strings.Contains(resp.AuthorizeUrl, "evil.example.com") {
		t.Fatalf("攻击者站点不得出现在授权链接里: %s", resp.AuthorizeUrl)
	}
}

func TestWechatAppFlowBindsServerState(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	wx := oauthtest.NewWechat(t)
	store := oauthtest.OpenStore(t)
	txs := oauthflow.Default()

	authResp, err := userbiz.WechatAuthorizeURL(ctx, txs, &userv1.WechatAuthorizeURLReq{
		Flow: "app", CodeChallenge: oauthtest.Challenge,
	})
	if err != nil {
		t.Fatalf("app flow 不需要回跳地址（SDK 在进程内返回 code）: %v", err)
	}
	if authResp.AuthorizeUrl != "" {
		t.Fatalf("app flow 不应下发授权页地址，got %q", authResp.AuthorizeUrl)
	}
	if authResp.State == "" || authResp.State == "moe_social" {
		t.Fatalf("app flow 必须拿到服务端随机 state，got %q", authResp.State)
	}

	resp, err := userbiz.WechatLogin(ctx, store, txs, &userv1.WechatLoginReq{
		Code:         oauthtest.WechatCode,
		State:        authResp.State,
		CodeVerifier: oauthtest.Verifier,
	})
	if err != nil {
		t.Fatalf("原生 SDK flow 登录应成功: %v", err)
	}
	if resp.Token == "" {
		t.Fatal("应下发 token")
	}
	_, appIDs := wx.Seen()
	if len(appIDs) != 1 || appIDs[0] != oauthtest.WechatAppAppID {
		t.Fatalf("app flow 应使用 wechat.app 凭证，got %v", appIDs)
	}

	// 同一 state 二次提交：取出即作废。
	if _, err := userbiz.WechatLogin(ctx, store, txs, &userv1.WechatLoginReq{
		Code: oauthtest.WechatCode, State: authResp.State, CodeVerifier: oauthtest.Verifier,
	}); !errors.Is(err, userbiz.ErrUnauthorized) {
		t.Fatalf("state 重放应 ErrUnauthorized，got %v", err)
	}
}

func TestWechatLoginRejectsFlowAndCredentialMixups(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	wx := oauthtest.NewWechat(t)
	store := oauthtest.OpenStore(t)
	txs := oauthflow.Default()

	// 1) 声称 flow=app 绕过绑定：发起的是 website 事务（有回跳地址），
	//    却用 state+code 直接提交。服务端 flow 以事务为准，必须拒绝。
	webResp, err := userbiz.WechatAuthorizeURL(ctx, txs, &userv1.WechatAuthorizeURLReq{
		Flow: "website", ReturnUrl: oauthtest.ListedReturnURL, CodeChallenge: oauthtest.Challenge,
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := userbiz.WechatLogin(ctx, store, txs, &userv1.WechatLoginReq{
		Code: oauthtest.WechatCode, Flow: "app", State: webResp.State, CodeVerifier: oauthtest.Verifier,
	}); !errors.Is(err, userbiz.ErrInvalidArgument) {
		t.Fatalf("website 事务不得被当 app flow 提交，got %v", err)
	}

	// 2) app 事务反过来拿去走 ticket：app flow 不经浏览器回调，不可能有票。
	appResp, err := userbiz.WechatAuthorizeURL(ctx, txs, &userv1.WechatAuthorizeURLReq{
		Flow: "app", CodeChallenge: oauthtest.Challenge,
	})
	if err != nil {
		t.Fatal(err)
	}

	// 3) ticket 与 state 同时提供。
	_, ticket, _ := runWechatBrowserAuth(t, ctx, txs, "website", oauthtest.ListedReturnURL)
	if _, err := userbiz.WechatLogin(ctx, store, txs, &userv1.WechatLoginReq{
		Ticket: ticket, State: appResp.State, CodeVerifier: oauthtest.Verifier,
	}); !errors.Is(err, userbiz.ErrInvalidArgument) {
		t.Fatalf("ticket 与 state 并存应拒绝，got %v", err)
	}

	// 4) 浏览器 flow 还自带 code（旧协议 / 注入他人授权码）。
	if _, err := userbiz.WechatLogin(ctx, store, txs, &userv1.WechatLoginReq{
		Ticket: ticket, Code: oauthtest.WechatCode, CodeVerifier: oauthtest.Verifier,
	}); !errors.Is(err, userbiz.ErrInvalidArgument) {
		t.Fatalf("ticket 与 code 并存应拒绝，got %v", err)
	}

	// 5) 什么都没有（旧 code-only 通路）。
	if _, err := userbiz.WechatLogin(ctx, store, txs, &userv1.WechatLoginReq{
		Code: oauthtest.WechatCode, Flow: "app",
	}); !errors.Is(err, userbiz.ErrInvalidArgument) {
		t.Fatalf("无 state 无 ticket 应拒绝，got %v", err)
	}

	// 6) app flow 只给 state 不给 code。
	if _, err := userbiz.WechatLogin(ctx, store, txs, &userv1.WechatLoginReq{
		State: appResp.State, CodeVerifier: oauthtest.Verifier,
	}); !errors.Is(err, userbiz.ErrInvalidArgument) {
		t.Fatalf("app flow 缺 code 应拒绝，got %v", err)
	}

	// 7) app 事务的 state 拿去配 ticket 字段。
	if _, err := userbiz.WechatLogin(ctx, store, txs, &userv1.WechatLoginReq{
		Ticket: appResp.State, CodeVerifier: oauthtest.Verifier,
	}); !errors.Is(err, userbiz.ErrUnauthorized) {
		t.Fatalf("state 不能当 ticket 用，got %v", err)
	}

	if codes, _ := wx.Seen(); len(codes) != 0 {
		t.Fatalf("以上全部为拒绝路径，不得触达供应商，got %v", codes)
	}
}

func TestWechatNativeCallbackWithoutReturnURLFailsClosed(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	txs := oauthflow.Default()

	// app flow 的事务没有登记回跳地址；万一它被拖到浏览器回调，
	// 必须明确失败，且绝不把授权码印在页面上或塞进 Location。
	authResp, err := userbiz.WechatAuthorizeURL(ctx, txs, &userv1.WechatAuthorizeURLReq{
		Flow: "app", CodeChallenge: oauthtest.Challenge,
	})
	if err != nil {
		t.Fatal(err)
	}
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/auth/wechat/callback", nil)
	userbiz.HandleWechatOAuthCallback(rec, req, userbiz.WechatOAuthCallbackInput{
		Code: oauthtest.WechatCode, State: authResp.State,
	})
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("应 500，got %d", rec.Code)
	}
	if loc := rec.Header().Get("Location"); loc != "" {
		t.Fatalf("不得回跳，Location=%q", loc)
	}
	if body := rec.Body.String(); strings.Contains(body, oauthtest.WechatCode) {
		t.Fatalf("失败页不得显示授权码: %s", body)
	}
}

// ---------------------------------------------------------------- 生命周期

func TestProcessRestartInvalidatesTicket(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	store := oauthtest.OpenStore(t)
	old := oauthflow.NewStore()

	tx, err := old.BeginAuth(oauthflow.ProviderFeishu, "", oauthtest.ListedReturnURL, oauthtest.Challenge)
	if err != nil {
		t.Fatal(err)
	}
	ticket, err := old.IssueTicket(tx, oauthtest.FeishuCode)
	if err != nil {
		t.Fatal(err)
	}

	// 事务存储是进程内存态：重启后新实例里没有这张票，必须失效而不是放行。
	restarted := oauthflow.NewStore()
	if _, err := userbiz.FeishuLogin(ctx, store, restarted, &userv1.FeishuLoginReq{
		Ticket: ticket, CodeVerifier: oauthtest.Verifier,
	}); !errors.Is(err, userbiz.ErrUnauthorized) {
		t.Fatalf("重启后旧 ticket 应失效，got %v", err)
	}
}

func TestExpiredTicketRejected(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	store := oauthtest.OpenStore(t)

	now := time.Unix(1700000000, 0)
	txs := oauthflow.NewStore(
		oauthflow.WithClock(func() time.Time { return now }),
		oauthflow.WithTicketTTL(60*time.Second),
	)
	tx, err := txs.BeginAuth(oauthflow.ProviderFeishu, "", oauthtest.ListedReturnURL, oauthtest.Challenge)
	if err != nil {
		t.Fatal(err)
	}
	ticket, err := txs.IssueTicket(tx, oauthtest.FeishuCode)
	if err != nil {
		t.Fatal(err)
	}

	now = now.Add(61 * time.Second)
	if _, err := userbiz.FeishuLogin(ctx, store, txs, &userv1.FeishuLoginReq{
		Ticket: ticket, CodeVerifier: oauthtest.Verifier,
	}); !errors.Is(err, userbiz.ErrUnauthorized) {
		t.Fatalf("过期 ticket 应 ErrUnauthorized，got %v", err)
	}
}

func TestExpiredStateRejected(t *testing.T) {
	oauthtest.LoadConfig(t)

	now := time.Unix(1700000000, 0)
	txs := oauthflow.NewStore(
		oauthflow.WithClock(func() time.Time { return now }),
		oauthflow.WithAuthTTL(10*time.Minute),
	)
	tx, err := txs.BeginAuth(oauthflow.ProviderFeishu, "", oauthtest.ListedReturnURL, oauthtest.Challenge)
	if err != nil {
		t.Fatal(err)
	}
	now = now.Add(11 * time.Minute)

	// 覆盖「用户在供应商页面停留过久才回来」这条真实路径。
	if _, err := txs.ConsumeState(tx.State); !errors.Is(err, oauthflow.ErrStateUnknown) {
		t.Fatalf("过期 state 应失效，got %v", err)
	}
}

func TestConcurrentLoginConsumesTicketOnce(t *testing.T) {
	ctx := oauthtest.LoadConfig(t)
	fs := oauthtest.NewFeishu(t)
	store := oauthtest.OpenStore(t)
	txs := oauthflow.Default()

	_, ticket, _ := runFeishuBrowserAuth(t, ctx, txs, oauthtest.ListedReturnURL)

	const workers = 24
	var (
		wg      sync.WaitGroup
		start   = make(chan struct{})
		mu      sync.Mutex
		success int
	)
	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			if _, err := userbiz.FeishuLogin(ctx, store, txs, &userv1.FeishuLoginReq{
				Ticket: ticket, CodeVerifier: oauthtest.Verifier,
			}); err == nil {
				mu.Lock()
				success++
				mu.Unlock()
			}
		}()
	}
	close(start)
	wg.Wait()

	if success != 1 {
		t.Fatalf("同一张 ticket 并发登录必须恰好成功一次，实际 %d 次", success)
	}
	if codes := fs.SeenCodes(); len(codes) != 1 {
		t.Fatalf("供应商授权码只应被兑换一次，got %v", codes)
	}
}
