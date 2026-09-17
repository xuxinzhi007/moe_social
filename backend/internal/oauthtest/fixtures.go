// Package oauthtest 为 #50 的服务端验收提供可复用的 OAuth 测试夹具：
// 假飞书 / 假微信开放平台、隔离配置、sqlite 内存账号库。
//
// 它只被 *_test.go 引用。存在的理由是同一套夹具要同时服务两层验收 ——
// internal/biz/user 的函数级链路，和 internal/server 的真实 HTTP 路由级链路。
// 两边各抄一份的话，假供应商的行为漂移就会让「哪一层坏了」变得无法判断。
//
// 所有夹具都不触网、不连 MySQL、不启动普通后端：供应商出网目标被
// utils.OverrideOAuthAPIBaseForTest 改写到 127.0.0.1，DB 是 sqlite 内存库。
package oauthtest

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"

	userbiz "backend/internal/biz/user"
	userdata "backend/internal/data/user"
	"backend/model"
	"backend/pkg/conf"
	"backend/utils"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

const (
	// RFC 7636 附录 B 的公开向量：verifier 与 challenge 是标准里给定的配对，
	// 用它当夹具可以同时证明「S256 实现正确」与「绑定校验生效」。
	Verifier  = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
	Challenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
	// 形状合法（43 位、字符集内）但 SHA256 对不上，用来验证 verifier 绑定。
	WrongVerifier = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

	// ListedReturnURL 在白名单里；EvilReturnURL 不在。
	ListedReturnURL = "https://app.example.com/login"
	EvilReturnURL   = "https://evil.example.com/collect"
	// NativeReturnURL 是 App 的 deep link，同样在白名单里。
	NativeReturnURL = "moesocial://feishu/oauth"

	FeishuCode = "feishu-code-abc123"
	WechatCode = "wechat-code-xyz789"

	FeishuName        = "飞书测试用户"
	FeishuOpenID      = "ou_oauth_test"
	WechatNickname    = "微信测试用户"
	WechatOpenID      = "o_wx_test"
	WechatAppAppID    = "wx_app_test"
	WechatWebAppID    = "wx_web_test"
	WechatMPAppID     = "wx_mp_test"
	FeishuCallbackURI = "http://127.0.0.1:8888/api/auth/feishu/callback"
)

// configYAML 是夹具用的完整配置：只开 OAuth 相关段落，不含任何真实凭据。
const configYAML = `
api:
  public_base_url: "http://127.0.0.1:8888"
auth:
  access_secret: "oauth-test-secret"
  access_expire_seconds: 3600
feishu:
  enabled: true
  app_id: "cli_oauth_test"
  app_secret: "secret_oauth_test"
wechat:
  enabled: true
  app:
    app_id: "wx_app_test"
    app_secret: "wx_app_secret"
  website:
    app_id: "wx_web_test"
    app_secret: "wx_web_secret"
  mp:
    app_id: "wx_mp_test"
    app_secret: "wx_mp_secret"
oauth:
  allowed_return_urls:
    - "https://app.example.com/login"
    - "moesocial://feishu/oauth"
    - "moesocial://wechat/oauth"
  auth_ttl_seconds: 600
  ticket_ttl_seconds: 60
  max_pending_auths: 64
`

// LoadConfig 把夹具配置写进临时目录并载入 conf，同时配好 JWT 签名密钥。
//
// conf 是进程级单例，所以调用方不得 t.Parallel()；用例结束时自动 ResetForTest。
// 传入的 mutate 用于按用例改写 YAML 文本（例如把 feishu.enabled 改成 false）。
func LoadConfig(t *testing.T, mutate ...func(yaml string) string) context.Context {
	t.Helper()
	yaml := configYAML
	for _, fn := range mutate {
		yaml = fn(yaml)
	}
	path := filepath.Join(t.TempDir(), "config.yaml")
	if err := os.WriteFile(path, []byte(yaml), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := conf.LoadFile(path); err != nil {
		t.Fatalf("load test config: %v", err)
	}
	t.Cleanup(conf.ResetForTest)
	if err := utils.ConfigureJWT("oauth-test-secret", 3600); err != nil {
		t.Fatal(err)
	}
	return context.Background()
}

// OpenStore 开一个 sqlite 内存库并只迁移 users 表 —— OAuth 登录链路只碰它。
func OpenStore(t *testing.T) userbiz.UserStore {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Skip("sqlite in-memory test requires CGO")
	}
	if err := db.AutoMigrate(&model.User{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return userdata.NewUserStore(db)
}

// --------------------------------------------------------------- 假飞书

// Feishu 是假飞书开放平台，覆盖登录链路会打到的四个端点。
type Feishu struct {
	// FailExchange 置真时，oidc 换 token 直接报错，用来验证供应商失败不会变成假成功。
	FailExchange bool

	mu    sync.Mutex
	codes []string
}

// SeenCodes 返回假飞书收到过的原始授权码，按到达顺序。
func (f *Feishu) SeenCodes() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]string(nil), f.codes...)
}

// NewFeishu 起假飞书并把 utils 的出网目标改写到它，用例结束自动还原。
func NewFeishu(t *testing.T) *Feishu {
	t.Helper()
	f := &Feishu{}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/auth/v3/tenant_access_token/internal":
			_, _ = w.Write([]byte(`{"code":0,"msg":"ok","tenant_access_token":"t-app-token","expire":7200}`))
		case "/authen/v1/oidc/access_token":
			var body struct {
				Code string `json:"code"`
			}
			_ = json.NewDecoder(r.Body).Decode(&body)
			f.mu.Lock()
			f.codes = append(f.codes, body.Code)
			fail := f.FailExchange
			f.mu.Unlock()
			if fail {
				_, _ = w.Write([]byte(`{"code":99991663,"msg":"invalid code"}`))
				return
			}
			_, _ = w.Write([]byte(`{"code":0,"msg":"ok","data":{"access_token":"u-access-token"}}`))
		case "/authen/v1/user_info":
			_, _ = w.Write([]byte(`{"code":0,"msg":"ok","data":{"open_id":"` + FeishuOpenID +
				`","union_id":"on_oauth_test","name":"` + FeishuName +
				`","email":"oauth.tester@feishu.test","avatar_url":"https://cdn.example.com/fs.png"}}`))
		case "/contact/v3/users":
			_, _ = w.Write([]byte(`{"code":0,"msg":"ok","data":{}}`))
		default:
			w.WriteHeader(http.StatusNotFound)
			_, _ = w.Write([]byte(`{"code":404,"msg":"unexpected path"}`))
		}
	}))
	t.Cleanup(srv.Close)
	restore, err := utils.OverrideOAuthAPIBaseForTest("feishu", srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(restore)
	return f
}

// --------------------------------------------------------------- 假微信

// Wechat 是假微信开放平台。
type Wechat struct {
	// scope 决定 ExchangeWechatOAuthCode 会不会再拉一次 /sns/userinfo：
	// 只有 scope 含 snsapi_userinfo 且 access_token 非空时才拉。
	// 真实微信 website(qrconnect) flow 回的是 snsapi_login，mp flow 回 snsapi_userinfo。
	// 必须在 NewWechat 时定好 —— 服务启动后再改会与 handler 的读取形成数据竞争。
	scope string

	mu           sync.Mutex
	codes        []string
	appIDs       []string
	userinfoHits int
}

// Seen 返回假微信收到过的授权码与 appid（据此可判断服务端用的是哪条 flow 的凭证）。
func (f *Wechat) Seen() (codes, appIDs []string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]string(nil), f.codes...), append([]string(nil), f.appIDs...)
}

// ProfileFetches 返回 /sns/userinfo 被调用的次数。
func (f *Wechat) ProfileFetches() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.userinfoHits
}

// NewWechat 起假微信。scope 省略时为 snsapi_login（website flow 的真实回包）。
func NewWechat(t *testing.T, scope ...string) *Wechat {
	t.Helper()
	f := &Wechat{scope: "snsapi_login"}
	if len(scope) > 0 && strings.TrimSpace(scope[0]) != "" {
		f.scope = scope[0]
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		q := r.URL.Query()
		switch r.URL.Path {
		case "/sns/oauth2/access_token":
			f.mu.Lock()
			f.codes = append(f.codes, q.Get("code"))
			f.appIDs = append(f.appIDs, q.Get("appid"))
			f.mu.Unlock()
			_ = json.NewEncoder(w).Encode(map[string]any{
				"access_token": "wx-access-token",
				"expires_in":   7200,
				"openid":       WechatOpenID,
				"scope":        f.scope,
				"unionid":      "u_wx_test",
				"errcode":      0,
			})
		case "/sns/userinfo":
			f.mu.Lock()
			f.userinfoHits++
			f.mu.Unlock()
			_, _ = w.Write([]byte(`{"openid":"` + WechatOpenID + `","nickname":"` + WechatNickname +
				`","headimgurl":"https://cdn.example.com/wx.png","unionid":"u_wx_test","errcode":0}`))
		default:
			w.WriteHeader(http.StatusNotFound)
			_, _ = w.Write([]byte(`{"errcode":404,"errmsg":"unexpected path"}`))
		}
	}))
	t.Cleanup(srv.Close)
	restore, err := utils.OverrideOAuthAPIBaseForTest("wechat", srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(restore)
	return f
}
