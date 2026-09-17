package oauthflow

import (
	"bytes"
	"errors"
	"io"
	"sync"
	"testing"
	"time"
)

// RFC 7636 附录 B 的公开测试向量。用标准里的定值而不是自己算一遍再断言，
// 才能真正证明 S256 实现与协议一致（自己算自己等于什么都没验证）。
const (
	rfcVerifier  = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
	rfcChallenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
)

const (
	testReturnURL   = "https://app.example.com/login"
	testNativeURL   = "moesocial://feishu/oauth"
	testEvilURL     = "https://evil.example.com/collect"
	testChallengeOK = rfcChallenge
)

// newTestStore 构造一个不碰 conf 的 Store：白名单、配置身份、TTL、时钟全部注入。
// 需要推进时间的用例自行 NewStore（见下方 expiry / 容量 / 随机源用例）。
func newTestStore(t *testing.T, now time.Time, allowed ...string) *Store {
	t.Helper()
	if len(allowed) == 0 {
		allowed = []string{testReturnURL, testNativeURL, "moesocial://wechat/oauth"}
	}
	return NewStore(
		WithClock(func() time.Time { return now }),
		WithAllowedReturnURLs(allowed),
		WithConfigIdentity(func(provider, flow string) string { return "app-id-" + provider + "-" + flow }),
		WithAuthTTL(10*time.Minute),
		WithTicketTTL(60*time.Second),
		WithMaxPending(4),
	)
}

func TestS256ChallengeMatchesRFC7636Vector(t *testing.T) {
	if got := S256Challenge(rfcVerifier); got != rfcChallenge {
		t.Fatalf("S256(%q) = %q, want %q", rfcVerifier, got, rfcChallenge)
	}
}

func TestVerifierAndChallengeShapes(t *testing.T) {
	if !ValidVerifier(rfcVerifier) {
		t.Fatal("RFC verifier must be accepted")
	}
	short := rfcVerifier[:42]
	if ValidVerifier(short) {
		t.Fatalf("42-char verifier must be rejected, got accepted: %q", short)
	}
	long := rfcVerifier + string(make([]byte, 86))
	if ValidVerifier(long) {
		t.Fatal("over-long verifier must be rejected")
	}
	if ValidVerifier(rfcVerifier + "+") {
		t.Fatal("'+' is not in the RFC 7636 unreserved set")
	}
	if ValidVerifier(rfcVerifier + "=") {
		t.Fatal("base64 padding must be rejected: 客户端忘了去填充要立刻暴露")
	}
	if !ValidChallenge(rfcChallenge) {
		t.Fatal("RFC challenge must be accepted")
	}
	if ValidChallenge(rfcChallenge + "=") {
		t.Fatal("padded challenge must be rejected")
	}
	if ValidChallenge(rfcChallenge[:42]) {
		t.Fatal("short challenge must be rejected")
	}
	if ValidChallenge(rfcChallenge + "A") {
		t.Fatal("over-long challenge must be rejected")
	}
}

func TestValidateReturnURL(t *testing.T) {
	rejected := []string{
		"",
		"   ",
		"/",
		"javascript:alert(1)",
		"data:text/html,<script>alert(1)</script>",
		"file:///etc/passwd",
		"moesocialx://feishu/oauth",
		"https://user:pass@app.example.com/login",
		"https://app.example.com/login?next=/admin",
		"https://app.example.com/login#frag",
		"https://app.example.com/login?",
		"//app.example.com/login",
		"app.example.com/login",
		"://broken",
	}
	for _, raw := range rejected {
		if err := ValidateReturnURL(raw); err == nil {
			t.Errorf("ValidateReturnURL(%q) must fail", raw)
		}
	}
	accepted := []string{
		"https://app.example.com/login",
		"http://localhost:8080",
		"http://192.168.124.36:8080",
		"moesocial://feishu/oauth",
		"moesocial://wechat/oauth",
	}
	for _, raw := range accepted {
		if err := ValidateReturnURL(raw); err != nil {
			t.Errorf("ValidateReturnURL(%q) = %v, want nil", raw, err)
		}
	}
}

func TestReturnURLAllowedIsExact(t *testing.T) {
	allowed := []string{testReturnURL, testNativeURL}
	cases := []struct {
		raw  string
		want bool
		why  string
	}{
		{testReturnURL, true, "白名单里的地址"},
		{testReturnURL + "/", true, "末尾斜杠等价（两边同样规范化）"},
		{"  " + testReturnURL + "  ", true, "首尾空白等价"},
		{testNativeURL, true, "原生 deep link"},
		{testEvilURL, false, "不在白名单"},
		{"https://app.example.com/login/../admin", false, "路径不同"},
		{"https://app.example.com:443/login", false, "显式端口与白名单写法不同即不放行"},
		{"http://app.example.com/login", false, "协议降级不放行"},
		{"https://app.example.com", false, "path 缺失"},
		{"https://app.example.com/login/extra", false, "多一段路径"},
		{"https://evil.example.com/collect", false, "攻击者站点"},
		{"https://app.example.com/login?x=1", false, "带 query 先被结构校验挡掉"},
	}
	for _, c := range cases {
		if got := ReturnURLAllowed(c.raw, allowed); got != c.want {
			t.Errorf("ReturnURLAllowed(%q) = %v, want %v (%s)", c.raw, got, c.want, c.why)
		}
	}
}

func TestReturnURLAllowedRejectsMalformedWhitelistEntries(t *testing.T) {
	// 白名单本身写错时必须登录失败，而不是静默放行一个畸形地址。
	if ReturnURLAllowed("javascript:alert(1)", []string{"javascript:alert(1)"}) {
		t.Fatal("畸形白名单条目不得被放行")
	}
	if ReturnURLAllowed(testEvilURL, []string{"", "   ", testEvilURL + "?x=1"}) {
		t.Fatal("只有结构合法的白名单条目才参与匹配")
	}
}

func TestAppendTicketQueryCarriesNoCode(t *testing.T) {
	got := AppendTicketQuery(testReturnURL, "TICKET123", "STATE456")
	want := testReturnURL + "?oauth_state=STATE456&oauth_ticket=TICKET123"
	if got != want {
		t.Fatalf("got %q, want %q", got, want)
	}
	for _, leak := range []string{"code=", "feishu_code", "wechat_code", "access_token", "verifier"} {
		if bytes.Contains([]byte(got), []byte(leak)) {
			t.Fatalf("回跳 URL 泄露了 %q: %s", leak, got)
		}
	}
}

func TestBeginAuthValidation(t *testing.T) {
	st := newTestStore(t, time.Unix(1700000000, 0))

	if _, err := st.BeginAuth("google", "", testReturnURL, testChallengeOK); !errors.Is(err, ErrUnknownProvider) {
		t.Fatalf("unknown provider: %v", err)
	}
	if _, err := st.BeginAuth(ProviderWechat, "mini", testReturnURL, testChallengeOK); !errors.Is(err, ErrUnknownFlow) {
		t.Fatalf("unknown flow: %v", err)
	}
	if _, err := st.BeginAuth(ProviderFeishu, "", testReturnURL, "not-a-challenge"); !errors.Is(err, ErrInvalidChallenge) {
		t.Fatalf("bad challenge: %v", err)
	}
	// 开放重定向的核心断言：攻击者站点不在白名单里，事务根本建不起来。
	if _, err := st.BeginAuth(ProviderFeishu, "", testEvilURL, testChallengeOK); !errors.Is(err, ErrReturnURLNotAllowed) {
		t.Fatalf("evil return_url: %v", err)
	}
	if _, err := st.BeginAuth(ProviderFeishu, "", "", testChallengeOK); !errors.Is(err, ErrReturnURLNotAllowed) {
		t.Fatalf("empty return_url: %v", err)
	}

	noCreds := NewStore(
		WithAllowedReturnURLs([]string{testReturnURL}),
		WithConfigIdentity(func(string, string) string { return "" }),
	)
	if _, err := noCreds.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK); !errors.Is(err, ErrProviderNotConfigured) {
		t.Fatalf("missing credentials: %v", err)
	}
}

func TestBeginAuthWechatAppNeedsNoReturnURL(t *testing.T) {
	st := newTestStore(t, time.Unix(1700000000, 0))
	tx, err := st.BeginAuth(ProviderWechat, "app", "", testChallengeOK)
	if err != nil {
		t.Fatal(err)
	}
	if tx.ReturnURL != "" {
		t.Fatalf("原生 flow 不该有回跳地址，got %q", tx.ReturnURL)
	}
	if tx.State == "" || len(tx.State) < 32 {
		t.Fatalf("state 必须是足够长的随机串，got %q", tx.State)
	}
	// 可预测的 state 等于没有 CSRF 防护。
	if tx.State == "moe_social" || tx.State == "moe_app" {
		t.Fatalf("state 不得是旧协议里的固定字面量，got %q", tx.State)
	}
}

func TestStatesAreUnpredictableAndUnique(t *testing.T) {
	st := newTestStore(t, time.Unix(1700000000, 0))
	seen := make(map[string]struct{}, 64)
	for i := 0; i < 64; i++ {
		tx, err := st.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK)
		if err != nil {
			t.Fatal(err)
		}
		if _, dup := seen[tx.State]; dup {
			t.Fatalf("state 重复: %q", tx.State)
		}
		seen[tx.State] = struct{}{}
	}
}

func TestConsumeStateIsOneShot(t *testing.T) {
	st := newTestStore(t, time.Unix(1700000000, 0))
	tx, err := st.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := st.ConsumeState(tx.State); err != nil {
		t.Fatal(err)
	}
	// 浏览器预取、用户刷新、攻击者重放都只有第一次能成功。
	if _, err := st.ConsumeState(tx.State); !errors.Is(err, ErrStateUnknown) {
		t.Fatalf("重放 state 必须失败，got %v", err)
	}
	if _, err := st.ConsumeState(""); !errors.Is(err, ErrStateUnknown) {
		t.Fatalf("空 state 必须失败，got %v", err)
	}
	if _, err := st.ConsumeState("never-issued"); !errors.Is(err, ErrStateUnknown) {
		t.Fatalf("伪造 state 必须失败，got %v", err)
	}
}

func TestConsumeStateExpires(t *testing.T) {
	base := time.Unix(1700000000, 0)
	current := base
	st := NewStore(
		WithClock(func() time.Time { return current }),
		WithAllowedReturnURLs([]string{testReturnURL}),
		WithConfigIdentity(func(string, string) string { return "app-id" }),
		WithAuthTTL(10*time.Minute),
		WithTicketTTL(60*time.Second),
		WithMaxPending(8),
	)
	tx, err := st.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK)
	if err != nil {
		t.Fatal(err)
	}
	current = base.Add(9 * time.Minute)
	if _, err := st.ConsumeState(tx.State); err != nil {
		t.Fatalf("TTL 内必须可用: %v", err)
	}

	tx2, err := st.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK)
	if err != nil {
		t.Fatal(err)
	}
	current = base.Add(20 * time.Minute)
	if _, err := st.ConsumeState(tx2.State); !errors.Is(err, ErrStateUnknown) {
		t.Fatalf("过期 state 必须失败，got %v", err)
	}
}

func TestConsumeStateRejectsConfigIdentityChange(t *testing.T) {
	base := time.Unix(1700000000, 0)
	identity := "app-id-old"
	st := NewStore(
		WithClock(func() time.Time { return base }),
		WithAllowedReturnURLs([]string{testReturnURL}),
		WithConfigIdentity(func(string, string) string { return identity }),
		WithAuthTTL(10*time.Minute),
		WithTicketTTL(60*time.Second),
		WithMaxPending(8),
	)
	tx, err := st.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK)
	if err != nil {
		t.Fatal(err)
	}
	// 授权途中运维换了供应商凭证：旧事务必须作废，而不是拿旧事务配新凭证。
	identity = "app-id-new"
	if _, err := st.ConsumeState(tx.State); !errors.Is(err, ErrStateUnknown) {
		t.Fatalf("配置身份变化后事务必须失效，got %v", err)
	}
}

func TestCapacityEvictsOldestInsteadOfRejecting(t *testing.T) {
	base := time.Unix(1700000000, 0)
	current := base
	st := NewStore(
		WithClock(func() time.Time { return current }),
		WithAllowedReturnURLs([]string{testReturnURL}),
		WithConfigIdentity(func(string, string) string { return "app-id" }),
		WithAuthTTL(10*time.Minute),
		WithMaxPending(3),
	)
	var states []string
	for i := 0; i < 3; i++ {
		current = base.Add(time.Duration(i) * time.Second)
		tx, err := st.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK)
		if err != nil {
			t.Fatal(err)
		}
		states = append(states, tx.State)
	}
	current = base.Add(3 * time.Second)
	newest, err := st.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK)
	if err != nil {
		t.Fatalf("容量满时应淘汰最旧的一条而不是拒绝新请求: %v", err)
	}
	if _, err := st.ConsumeState(states[0]); !errors.Is(err, ErrStateUnknown) {
		t.Fatal("最早到期的事务应已被淘汰")
	}
	if _, err := st.ConsumeState(states[1]); err != nil {
		t.Fatalf("中间的事务不该被淘汰: %v", err)
	}
	if _, err := st.ConsumeState(states[2]); err != nil {
		t.Fatalf("较新的事务不该被淘汰: %v", err)
	}
	if _, err := st.ConsumeState(newest.State); err != nil {
		t.Fatal(err)
	}
	if auths, _ := st.PendingCounts(); auths != 0 {
		t.Fatalf("全部消费后应无残留，got %d", auths)
	}
}

func TestZeroCapacityRefusesAuth(t *testing.T) {
	st := NewStore(
		WithAllowedReturnURLs([]string{testReturnURL}),
		WithConfigIdentity(func(string, string) string { return "app-id" }),
		WithMaxPending(0),
	)
	if _, err := st.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK); !errors.Is(err, ErrStoreFull) {
		t.Fatalf("容量 0 必须明确失败，got %v", err)
	}
}

func TestTicketRoundTripAndOneShot(t *testing.T) {
	base := time.Unix(1700000000, 0)
	current := base
	st := NewStore(
		WithClock(func() time.Time { return current }),
		WithAllowedReturnURLs([]string{testReturnURL}),
		WithConfigIdentity(func(string, string) string { return "app-id" }),
		WithAuthTTL(10*time.Minute),
		WithTicketTTL(60*time.Second),
		WithMaxPending(8),
	)
	tx, err := st.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK)
	if err != nil {
		t.Fatal(err)
	}
	consumed, err := st.ConsumeState(tx.State)
	if err != nil {
		t.Fatal(err)
	}
	ticket, err := st.IssueTicket(consumed, "provider-code-abc")
	if err != nil {
		t.Fatal(err)
	}
	if ticket == "" || ticket == "provider-code-abc" {
		t.Fatalf("ticket 必须是不含授权码的随机串，got %q", ticket)
	}

	tk, err := st.ConsumeTicket(ticket, rfcVerifier)
	if err != nil {
		t.Fatal(err)
	}
	if tk.Code != "provider-code-abc" || tk.Provider != ProviderFeishu {
		t.Fatalf("ticket 内容不符: %+v", tk)
	}
	if _, err := st.ConsumeTicket(ticket, rfcVerifier); !errors.Is(err, ErrTicketUnknown) {
		t.Fatalf("ticket 重放必须失败，got %v", err)
	}
}

func TestConsumeTicketVerifierBinding(t *testing.T) {
	st := newTestStore(t, time.Unix(1700000000, 0))
	tx, err := st.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK)
	if err != nil {
		t.Fatal(err)
	}
	consumed, _ := st.ConsumeState(tx.State)
	ticket, err := st.IssueTicket(consumed, "code-1")
	if err != nil {
		t.Fatal(err)
	}

	otherVerifier := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
	if _, err := st.ConsumeTicket(ticket, otherVerifier); !errors.Is(err, ErrChallengeMismatch) {
		t.Fatalf("错误 verifier 必须失败，got %v", err)
	}
	// 校验发生在删除之后：拿同一张 ticket 再试一次也不行。
	if _, err := st.ConsumeTicket(ticket, rfcVerifier); !errors.Is(err, ErrTicketUnknown) {
		t.Fatalf("verifier 试错后 ticket 必须已作废，got %v", err)
	}
	if _, err := st.ConsumeTicket("never-issued", rfcVerifier); !errors.Is(err, ErrTicketUnknown) {
		t.Fatalf("伪造 ticket 必须失败，got %v", err)
	}
	if _, err := st.ConsumeTicket("", rfcVerifier); !errors.Is(err, ErrTicketUnknown) {
		t.Fatalf("空 ticket 必须失败，got %v", err)
	}
}

func TestConsumeTicketExpiry(t *testing.T) {
	base := time.Unix(1700000000, 0)
	current := base
	st := NewStore(
		WithClock(func() time.Time { return current }),
		WithAllowedReturnURLs([]string{testReturnURL}),
		WithConfigIdentity(func(string, string) string { return "app-id" }),
		WithAuthTTL(10*time.Minute),
		WithTicketTTL(60*time.Second),
		WithMaxPending(8),
	)
	tx, _ := st.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK)
	consumed, _ := st.ConsumeState(tx.State)
	ticket, err := st.IssueTicket(consumed, "code-1")
	if err != nil {
		t.Fatal(err)
	}
	current = base.Add(61 * time.Second)
	if _, err := st.ConsumeTicket(ticket, rfcVerifier); !errors.Is(err, ErrTicketUnknown) {
		t.Fatalf("过期 ticket 必须失败，got %v", err)
	}
}

func TestIssueTicketRejectsEmptyCode(t *testing.T) {
	st := newTestStore(t, time.Unix(1700000000, 0))
	tx, _ := st.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK)
	consumed, _ := st.ConsumeState(tx.State)
	if _, err := st.IssueTicket(consumed, "   "); !errors.Is(err, ErrTicketUnknown) {
		t.Fatalf("空授权码不得签发 ticket，got %v", err)
	}
}

func TestConsumeStateWithVerifier(t *testing.T) {
	st := newTestStore(t, time.Unix(1700000000, 0))
	tx, err := st.BeginAuth(ProviderWechat, "app", "", testChallengeOK)
	if err != nil {
		t.Fatal(err)
	}
	got, err := st.ConsumeStateWithVerifier(tx.State, rfcVerifier)
	if err != nil {
		t.Fatal(err)
	}
	if got.Flow != "app" || got.Provider != ProviderWechat {
		t.Fatalf("事务内容不符: %+v", got)
	}

	tx2, _ := st.BeginAuth(ProviderWechat, "app", "", testChallengeOK)
	if _, err := st.ConsumeStateWithVerifier(tx2.State, "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"); !errors.Is(err, ErrChallengeMismatch) {
		t.Fatalf("错误 verifier 必须失败，got %v", err)
	}
	// 先删再比：verifier 试错同样烧掉 state。
	if _, err := st.ConsumeStateWithVerifier(tx2.State, rfcVerifier); !errors.Is(err, ErrStateUnknown) {
		t.Fatalf("verifier 试错后 state 必须已作废，got %v", err)
	}
	if _, err := st.ConsumeStateWithVerifier(tx2.State, "short"); !errors.Is(err, ErrStateUnknown) {
		t.Fatalf("已消费的 state 优先报失效，got %v", err)
	}
}

func TestConcurrentConsumptionSucceedsAtMostOnce(t *testing.T) {
	st := NewStore(
		WithAllowedReturnURLs([]string{testReturnURL}),
		WithConfigIdentity(func(string, string) string { return "app-id" }),
		WithAuthTTL(10*time.Minute),
		WithTicketTTL(60*time.Second),
		WithMaxPending(64),
	)
	tx, err := st.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK)
	if err != nil {
		t.Fatal(err)
	}
	consumed, err := st.ConsumeState(tx.State)
	if err != nil {
		t.Fatal(err)
	}
	ticket, err := st.IssueTicket(consumed, "code-1")
	if err != nil {
		t.Fatal(err)
	}

	const goroutines = 32
	var wg sync.WaitGroup
	var mu sync.Mutex
	wins := 0
	start := make(chan struct{})
	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			if _, err := st.ConsumeTicket(ticket, rfcVerifier); err == nil {
				mu.Lock()
				wins++
				mu.Unlock()
			}
		}()
	}
	close(start)
	wg.Wait()
	if wins != 1 {
		t.Fatalf("并发消费 ticket 必须至多成功一次，实际成功 %d 次", wins)
	}
}

func TestRandomFailureIsSurfaced(t *testing.T) {
	st := NewStore(
		WithRand(alwaysFailReader{}),
		WithAllowedReturnURLs([]string{testReturnURL}),
		WithConfigIdentity(func(string, string) string { return "app-id" }),
		WithMaxPending(8),
	)
	if _, err := st.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK); !errors.Is(err, ErrRandom) {
		t.Fatalf("随机源不可用必须明确失败，got %v", err)
	}
}

type alwaysFailReader struct{}

func (alwaysFailReader) Read([]byte) (int, error) { return 0, io.ErrUnexpectedEOF }

func TestPendingCountsIgnoresExpired(t *testing.T) {
	base := time.Unix(1700000000, 0)
	current := base
	st := NewStore(
		WithClock(func() time.Time { return current }),
		WithAllowedReturnURLs([]string{testReturnURL}),
		WithConfigIdentity(func(string, string) string { return "app-id" }),
		WithAuthTTL(time.Minute),
		WithTicketTTL(time.Minute),
		WithMaxPending(8),
	)
	if _, err := st.BeginAuth(ProviderFeishu, "", testReturnURL, testChallengeOK); err != nil {
		t.Fatal(err)
	}
	if auths, tickets := st.PendingCounts(); auths != 1 || tickets != 0 {
		t.Fatalf("got auths=%d tickets=%d", auths, tickets)
	}
	current = base.Add(2 * time.Minute)
	if auths, tickets := st.PendingCounts(); auths != 0 || tickets != 0 {
		t.Fatalf("过期后计数应为 0，got auths=%d tickets=%d", auths, tickets)
	}
}
