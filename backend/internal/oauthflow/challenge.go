// Package oauthflow 承载第三方登录（飞书 / 微信）的授权事务：
// 服务端随机 state、S256 challenge 绑定、一次性 ticket、精确回跳白名单。
//
// 它存在的理由是 #50：旧协议把客户端传来的 state 直接当回跳地址，且回调 302 时
// 把供应商授权码原样带上，于是任何人构造一个指向自己站点的 state 就能收走别人的
// 授权码并接管账号。新协议里 state 只是服务端签发的一次性句柄，回跳地址必须命中
// config.yaml 的精确白名单，授权码留在服务端、只以短期 ticket 的形式间接交付，
// 客户端还要出示当初发起授权时自己生成的 verifier 才能把 ticket 换成登录态。
//
// 事务只活在内存里：没有数据库表、没有 Redis，进程重启即全部失效（用户重新授权一次）。
// 这与当前的单进程部署一致；若将来拆多副本，这份存储必须换成共享实现，
// 否则回调落到另一个副本上会查不到 state。
package oauthflow

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"io"
)

// 供应商标识。事务与 ticket 都会记下它，登录时逐字段核对，
// 防止拿飞书的事务去兑换微信的 code（或反之）。
const (
	ProviderFeishu = "feishu"
	ProviderWechat = "wechat"
)

var (
	// ErrReturnURLNotAllowed 回跳地址未命中白名单或结构非法。
	ErrReturnURLNotAllowed = errors.New("oauthflow: 回跳地址不在可信白名单内")
	// ErrUnknownProvider 供应商不是 feishu / wechat。
	ErrUnknownProvider = errors.New("oauthflow: 未知的登录供应商")
	// ErrUnknownFlow 微信 flow 不是 app / website / mp。
	ErrUnknownFlow = errors.New("oauthflow: 未知的微信授权 flow")
	// ErrProviderNotConfigured 供应商凭证缺失，无法发起授权。
	ErrProviderNotConfigured = errors.New("oauthflow: 服务端未配置该登录方式")
	// ErrInvalidChallenge code_challenge 形状非法（非 base64url 或长度越界）。
	ErrInvalidChallenge = errors.New("oauthflow: code_challenge 非法")
	// ErrInvalidVerifier code_verifier 形状非法。
	ErrInvalidVerifier = errors.New("oauthflow: code_verifier 非法")
	// ErrChallengeMismatch verifier 与授权时登记的 challenge 不匹配。
	ErrChallengeMismatch = errors.New("oauthflow: code_verifier 与授权事务不匹配")
	// ErrStateUnknown state 不存在、已过期或已被消费。对外一律同一句话，
	// 不区分「没见过」和「用过了」，避免给攻击者做状态探测。
	ErrStateUnknown = errors.New("oauthflow: 授权事务不存在或已失效")
	// ErrTicketUnknown ticket 不存在、已过期或已被消费。
	ErrTicketUnknown = errors.New("oauthflow: 授权票据不存在或已失效")
	// ErrStoreFull 待处理授权事务已达容量上限。
	ErrStoreFull = errors.New("oauthflow: 待处理授权事务已满")
	// ErrRandom 安全随机源不可用。
	ErrRandom = errors.New("oauthflow: 无法生成安全随机数")
)

const (
	// minVerifierLen / maxVerifierLen 取自 RFC 7636 §4.1。
	minVerifierLen = 43
	maxVerifierLen = 128
	// challengeLen 是 base64url(SHA256(...)) 的固定长度：32 字节 → 43 字符（无填充）。
	challengeLen = 43
	// stateBytes / ticketBytes 是随机句柄的熵。32 字节 = 256 bit，
	// 在 10 分钟 / 60 秒的存活窗口内不可枚举。
	stateBytes  = 32
	ticketBytes = 32
)

// S256Challenge 由 verifier 计算 challenge：BASE64URL-ENCODE(SHA256(ASCII(verifier)))，无填充。
func S256Challenge(verifier string) string {
	sum := sha256.Sum256([]byte(verifier))
	return base64.RawURLEncoding.EncodeToString(sum[:])
}

// ValidVerifier 校验 verifier 形状：长度 43..128，字符集 [A-Za-z0-9-._~]（RFC 7636 §4.1）。
//
// 形状校验不是为了安全（安全来自 challenge 比对），而是为了把明显错误的输入挡在
// SHA256 之前，并让客户端的编码错误（比如忘了去掉 base64 填充）立刻暴露而不是
// 表现成一次莫名的 challenge 不匹配。
func ValidVerifier(v string) bool {
	if len(v) < minVerifierLen || len(v) > maxVerifierLen {
		return false
	}
	for i := 0; i < len(v); i++ {
		c := v[i]
		switch {
		case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9':
		case c == '-', c == '.', c == '_', c == '~':
		default:
			return false
		}
	}
	return true
}

// ValidChallenge 校验 challenge 形状：43 字符的 base64url（无填充）。
func ValidChallenge(c string) bool {
	if len(c) != challengeLen {
		return false
	}
	if _, err := base64.RawURLEncoding.DecodeString(c); err != nil {
		return false
	}
	return true
}

// randomToken 生成 base64url（无填充）随机句柄。
func randomToken(r io.Reader, n int) (string, error) {
	if r == nil {
		r = rand.Reader
	}
	b := make([]byte, n)
	// io.ReadFull：rand.Reader 短读会返回 err，但显式用 ReadFull 才能确保
	// 半填充的 buffer 不会被当成有效熵使用。
	if _, err := io.ReadFull(r, b); err != nil {
		return "", ErrRandom
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}
