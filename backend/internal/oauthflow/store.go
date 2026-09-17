package oauthflow

import (
	"crypto/rand"
	"io"
	"strings"
	"sync"
	"time"

	"backend/pkg/conf"
)

// AuthTx 一次授权请求在服务端登记的事务。
//
// State 是交给供应商、再由供应商原样带回回调的句柄；它不含任何语义，
// 只是一个 256 bit 随机串。回跳地址、challenge、供应商配置身份都留在服务端，
// 客户端与供应商都看不到，也就无从篡改。
type AuthTx struct {
	State         string
	Provider      string
	Flow          string
	ReturnURL     string
	CodeChallenge string
	ConfigID      string
	ExpiresAt     time.Time
}

// Ticket 回调签发的一次性凭证。供应商授权码只存在这里，从不出现在回跳 URL 中。
type Ticket struct {
	ID            string
	Provider      string
	Flow          string
	Code          string
	CodeChallenge string
	ConfigID      string
	ExpiresAt     time.Time
}

// wechatFlows 是微信三条 flow。飞书的 Flow 恒为空串（它只有一种网页授权）。
var wechatFlows = map[string]struct{}{"app": {}, "website": {}, "mp": {}}

// Store 是有界的进程内事务存储。
//
// 全部字段都在 mu 保护下访问。TTL 与容量以函数形式保存，缺省每次调用都回读 conf ——
// 这样管理台改完 config.yaml 并 Reload 之后，新发起的授权立刻用上新值，不必重启。
type Store struct {
	mu      sync.Mutex
	auths   map[string]*AuthTx
	tickets map[string]*Ticket

	clock       func() time.Time
	random      io.Reader
	authTTL     func() time.Duration
	ticketTTL   func() time.Duration
	maxPending  func() int
	configIdent func(provider, flow string) string
	allowedURLs func() []string
}

// Option 覆盖 Store 的缺省依赖，仅测试需要（注入假时钟 / 定长随机源 / 固定白名单）。
type Option func(*Store)

// WithClock 注入时钟，用于测过期而不真的等 10 分钟。
func WithClock(f func() time.Time) Option {
	return func(s *Store) {
		if f != nil {
			s.clock = f
		}
	}
}

// WithRand 注入随机源，用于断言 state/ticket 的生成路径；传 nil 恢复 crypto/rand。
func WithRand(r io.Reader) Option {
	return func(s *Store) { s.random = r }
}

// WithAuthTTL 固定授权事务有效期，不再回读 conf。
func WithAuthTTL(d time.Duration) Option {
	return func(s *Store) { s.authTTL = func() time.Duration { return d } }
}

// WithTicketTTL 固定 ticket 有效期，不再回读 conf。
func WithTicketTTL(d time.Duration) Option {
	return func(s *Store) { s.ticketTTL = func() time.Duration { return d } }
}

// WithMaxPending 固定容量上限，不再回读 conf。
func WithMaxPending(n int) Option {
	return func(s *Store) { s.maxPending = func() int { return n } }
}

// WithConfigIdentity 注入供应商配置身份计算，不再回读 conf。
func WithConfigIdentity(f func(provider, flow string) string) Option {
	return func(s *Store) {
		if f != nil {
			s.configIdent = f
		}
	}
}

// WithAllowedReturnURLs 注入回跳白名单，不再回读 conf。
func WithAllowedReturnURLs(urls []string) Option {
	return func(s *Store) {
		s.allowedURLs = func() []string { return urls }
	}
}

// NewStore 构造一个独立 Store。生产路径用 Default()；测试各自构造，互不干扰。
func NewStore(opts ...Option) *Store {
	s := &Store{
		auths:       make(map[string]*AuthTx),
		tickets:     make(map[string]*Ticket),
		clock:       time.Now,
		random:      rand.Reader,
		authTTL:     conf.OAuthAuthTTL,
		ticketTTL:   conf.OAuthTicketTTL,
		maxPending:  conf.OAuthMaxPendingAuths,
		configIdent: ConfigIdentity,
		allowedURLs: conf.OAuthAllowedReturnURLs,
	}
	for _, opt := range opts {
		opt(s)
	}
	return s
}

var defaultStore = NewStore()

// Default 返回进程内共享的 Store。
//
// 「共享」是必需的：发起授权的 HTTP 请求、供应商回调、以及随后的 login 请求
// 是三次独立的请求，只有同一份存储才能把它们串起来。
func Default() *Store { return defaultStore }

// ConfigIdentity 计算供应商配置身份：飞书取 app_id，微信按 flow 取对应 app_id。
//
// 事务里记下它、消费时再比一次，是为了让「授权途中运维换了供应商凭证」这种
// 半截状态明确失败，而不是拿旧事务去配新凭证换一个必然被拒的 code。
// 取不到（凭证缺失）时返回空串，BeginAuth 会据此拒绝发起授权。
func ConfigIdentity(provider, flow string) string {
	switch provider {
	case ProviderFeishu:
		return strings.TrimSpace(conf.Get().Feishu.AppID)
	case ProviderWechat:
		appID, _, err := conf.WechatFlowCredential(flow)
		if err != nil {
			return ""
		}
		return strings.TrimSpace(appID)
	default:
		return ""
	}
}

// BeginAuth 校验入参、生成随机 state 并登记授权事务。
//
// returnURL 只在浏览器回跳链路（飞书全部、微信 website/mp）需要；微信 app flow 由
// 原生 SDK 在进程内直接返回 code，没有 302，传空即可。flow 必须是已规范化的值
// （app|website|mp），规范化由调用方用 utils.NormalizeWechatOAuthFlow 完成 ——
// 本包不导入 utils，避免与它形成循环依赖。
func (s *Store) BeginAuth(provider, flow, returnURL, codeChallenge string) (AuthTx, error) {
	switch provider {
	case ProviderFeishu:
		// 飞书只有一种网页授权，flow 恒为空；调用方传了也忽略，避免无谓的拒绝。
		flow = ""
	case ProviderWechat:
		if _, ok := wechatFlows[flow]; !ok {
			return AuthTx{}, ErrUnknownFlow
		}
	default:
		return AuthTx{}, ErrUnknownProvider
	}
	if !ValidChallenge(codeChallenge) {
		return AuthTx{}, ErrInvalidChallenge
	}

	nativeApp := provider == ProviderWechat && flow == "app"
	resolvedReturn := ""
	if !nativeApp {
		if !ReturnURLAllowed(returnURL, s.allowedURLs()) {
			return AuthTx{}, ErrReturnURLNotAllowed
		}
		resolvedReturn = NormalizeReturnURL(returnURL)
	}

	configID := s.configIdent(provider, flow)
	if configID == "" {
		// 凭证缺失：与其发一个注定兑换失败的 state，不如现在就报错。
		return AuthTx{}, ErrProviderNotConfigured
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	now := s.clock()
	s.purgeExpiredLocked(now)
	if !s.makeRoomLocked(s.maxPending()) {
		return AuthTx{}, ErrStoreFull
	}

	state, err := randomToken(s.random, stateBytes)
	if err != nil {
		return AuthTx{}, err
	}
	if _, exists := s.auths[state]; exists {
		// 256 bit 随机串撞车在物理上不会发生；真撞上说明随机源坏了，
		// 此时绝不能复用旧事务，直接失败。
		return AuthTx{}, ErrRandom
	}
	tx := AuthTx{
		State:         state,
		Provider:      provider,
		Flow:          flow,
		ReturnURL:     resolvedReturn,
		CodeChallenge: codeChallenge,
		ConfigID:      configID,
		ExpiresAt:     now.Add(s.authTTL()),
	}
	s.auths[state] = &tx
	return tx, nil
}

// ConsumeState 原子取出并删除一条授权事务。
//
// 「取出即删除」是防重放的关键：供应商回调可能被浏览器预取、被用户刷新、
// 被攻击者重放，只有第一次能拿到事务，其余全部失败。
func (s *Store) ConsumeState(state string) (AuthTx, error) {
	state = strings.TrimSpace(state)
	if state == "" {
		return AuthTx{}, ErrStateUnknown
	}
	s.mu.Lock()
	defer s.mu.Unlock()

	tx, ok := s.auths[state]
	if !ok {
		return AuthTx{}, ErrStateUnknown
	}
	delete(s.auths, state)

	now := s.clock()
	if !tx.ExpiresAt.After(now) {
		return AuthTx{}, ErrStateUnknown
	}
	if s.configIdent(tx.Provider, tx.Flow) != tx.ConfigID {
		return AuthTx{}, ErrStateUnknown
	}
	return *tx, nil
}

// ConsumeStateWithVerifier 取出授权事务并立即校验 verifier。
//
// 给微信原生 SDK flow 用：那条链路里 code 由 SDK 在进程内直接返回，没有浏览器回调，
// 因而没有 ticket，只能直接消费 state。校验顺序与 ConsumeTicket 一致 ——
// **先删除再比对**：即便 verifier 错误，这个 state 也已经作废，
// 否则攻击者可以拿同一个 state 反复试 verifier。
func (s *Store) ConsumeStateWithVerifier(state, codeVerifier string) (AuthTx, error) {
	tx, err := s.ConsumeState(state)
	if err != nil {
		return AuthTx{}, err
	}
	if !ValidVerifier(codeVerifier) {
		return AuthTx{}, ErrInvalidVerifier
	}
	if S256Challenge(codeVerifier) != tx.CodeChallenge {
		return AuthTx{}, ErrChallengeMismatch
	}
	return tx, nil
}

// IssueTicket 用已消费的授权事务换取一次性 ticket，并把供应商授权码封存在 ticket 里。
func (s *Store) IssueTicket(tx AuthTx, code string) (string, error) {
	code = strings.TrimSpace(code)
	if code == "" {
		return "", ErrTicketUnknown
	}
	id, err := randomToken(s.random, ticketBytes)
	if err != nil {
		return "", err
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	now := s.clock()
	s.purgeExpiredTicketsLocked(now)
	if !s.makeRoomTicketsLocked(s.maxPending()) {
		return "", ErrStoreFull
	}
	s.tickets[id] = &Ticket{
		ID:            id,
		Provider:      tx.Provider,
		Flow:          tx.Flow,
		Code:          code,
		CodeChallenge: tx.CodeChallenge,
		ConfigID:      tx.ConfigID,
		ExpiresAt:     now.Add(s.ticketTTL()),
	}
	return id, nil
}

// ConsumeTicket 原子取出并删除一条 ticket，随后校验 verifier 与配置身份。
//
// 校验放在删除之后：即便 verifier 错误，这张 ticket 也已经作废。
// 否则攻击者可以拿同一个 ticket 反复试 verifier。
func (s *Store) ConsumeTicket(id, codeVerifier string) (Ticket, error) {
	id = strings.TrimSpace(id)
	if id == "" {
		return Ticket{}, ErrTicketUnknown
	}
	if !ValidVerifier(codeVerifier) {
		return Ticket{}, ErrInvalidVerifier
	}

	s.mu.Lock()
	tk, ok := s.tickets[id]
	if ok {
		delete(s.tickets, id)
	}
	s.mu.Unlock()

	if !ok {
		return Ticket{}, ErrTicketUnknown
	}
	if !tk.ExpiresAt.After(s.clock()) {
		return Ticket{}, ErrTicketUnknown
	}
	if s.configIdent(tk.Provider, tk.Flow) != tk.ConfigID {
		return Ticket{}, ErrTicketUnknown
	}
	if S256Challenge(codeVerifier) != tk.CodeChallenge {
		return Ticket{}, ErrChallengeMismatch
	}
	return *tk, nil
}

// PendingCounts 返回当前未过期的授权事务与 ticket 数量，仅供测试与自检。
func (s *Store) PendingCounts() (auths, tickets int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := s.clock()
	for _, tx := range s.auths {
		if tx.ExpiresAt.After(now) {
			auths++
		}
	}
	for _, tk := range s.tickets {
		if tk.ExpiresAt.After(now) {
			tickets++
		}
	}
	return auths, tickets
}

func (s *Store) purgeExpiredLocked(now time.Time) {
	for k, tx := range s.auths {
		if !tx.ExpiresAt.After(now) {
			delete(s.auths, k)
		}
	}
}

func (s *Store) purgeExpiredTicketsLocked(now time.Time) {
	for k, tk := range s.tickets {
		if !tk.ExpiresAt.After(now) {
			delete(s.tickets, k)
		}
	}
}

// makeRoomLocked 在容量满时淘汰最早到期的一条授权事务。
//
// 淘汰而不是拒绝新请求：授权发起端点是公开的，拒绝新请求会让攻击者用满容量后
// 把所有正常用户永久挡在门外；淘汰最旧的只是让最旧的那次授权作废（用户重试即可）。
// 上限本身（缺省 4096，约 1 MB）才是防内存耗尽的那道闸。
func (s *Store) makeRoomLocked(max int) bool {
	if max <= 0 {
		return false
	}
	if len(s.auths) < max {
		return true
	}
	var oldestKey string
	var oldest time.Time
	for k, tx := range s.auths {
		if oldestKey == "" || tx.ExpiresAt.Before(oldest) {
			oldestKey, oldest = k, tx.ExpiresAt
		}
	}
	if oldestKey == "" {
		return false
	}
	delete(s.auths, oldestKey)
	return len(s.auths) < max
}

func (s *Store) makeRoomTicketsLocked(max int) bool {
	if max <= 0 {
		return false
	}
	if len(s.tickets) < max {
		return true
	}
	var oldestKey string
	var oldest time.Time
	for k, tk := range s.tickets {
		if oldestKey == "" || tk.ExpiresAt.Before(oldest) {
			oldestKey, oldest = k, tk.ExpiresAt
		}
	}
	if oldestKey == "" {
		return false
	}
	delete(s.tickets, oldestKey)
	return len(s.tickets) < max
}
