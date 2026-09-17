package oauthflow

import (
	"net/url"
	"strings"
)

// allowedSchemes 是回跳地址可接受的协议。
//
// moesocial 是 App 的原生 deep link（服务端 302 到它，由系统唤起 App）。
// 其余一律拒绝 —— 特别是 javascript: 与 data:：那两种能在浏览器里执行脚本，
// 一旦进了回跳目标就等于把 XSS 交给攻击者。
var allowedSchemes = map[string]struct{}{
	"http":      {},
	"https":     {},
	"moesocial": {},
}

// NormalizeReturnURL 规范化回跳地址：去首尾空白、去末尾斜杠。
//
// 必须与 conf.OAuthAllowedReturnURLs 对配置项施加的规范化**逐字一致**，
// 否则「配置里写了 http://x:8080」而客户端送来「http://x:8080/」会匹配不上。
// 刻意不做大小写折叠、不补默认端口、不重排 path —— 白名单是精确匹配，
// 多做一步归一化就等于放宽了它。
func NormalizeReturnURL(raw string) string {
	u := strings.TrimSpace(raw)
	for strings.HasSuffix(u, "/") {
		u = strings.TrimSuffix(u, "/")
	}
	return u
}

// ValidateReturnURL 做结构校验，不查白名单。
// 拒绝：无法解析、协议不在允许集、缺 host、带 userinfo、带 query、带 fragment。
//
// query 与 fragment 必须拒绝而不是「忽略后比较」：回跳时服务端会往这个地址上追加
// ?ticket=…，若原地址自带 query 就会出现两个 ? 或参数被覆盖；带 fragment 的地址
// 在 302 里行为也不确定。让用户把白名单写成干净的 origin+path，语义唯一。
func ValidateReturnURL(raw string) error {
	normalized := NormalizeReturnURL(raw)
	if normalized == "" {
		return ErrReturnURLNotAllowed
	}
	u, err := url.Parse(normalized)
	if err != nil {
		return ErrReturnURLNotAllowed
	}
	if _, ok := allowedSchemes[strings.ToLower(u.Scheme)]; !ok {
		return ErrReturnURLNotAllowed
	}
	if u.Host == "" {
		return ErrReturnURLNotAllowed
	}
	if u.User != nil {
		return ErrReturnURLNotAllowed
	}
	if u.RawQuery != "" || u.ForceQuery {
		return ErrReturnURLNotAllowed
	}
	if u.Fragment != "" || strings.Contains(normalized, "#") {
		return ErrReturnURLNotAllowed
	}
	return nil
}

// ReturnURLAllowed 报告 raw 是否命中白名单。
//
// 先过结构校验再逐项精确比对：结构校验挡住协议与 userinfo 之类的花样，
// 精确比对保证「只有运维明确写进 config.yaml 的那几个地址」能被跳回去。
// allowed 里的每一项也要过结构校验 —— 白名单本身写错时应当登录失败，
// 而不是静默放行一个畸形地址。
func ReturnURLAllowed(raw string, allowed []string) bool {
	if ValidateReturnURL(raw) != nil {
		return false
	}
	normalized := NormalizeReturnURL(raw)
	for _, item := range allowed {
		if ValidateReturnURL(item) != nil {
			continue
		}
		if NormalizeReturnURL(item) == normalized {
			return true
		}
	}
	return false
}

// AppendTicketQuery 把 ticket 与 state 拼到已校验的回跳地址上。
//
// 只带这两个参数：供应商授权码、JWT、verifier 一律不出现在回跳 URL 里。
// 浏览器地址栏、历史记录、Referer、代理日志都会留下 URL，把 code 放进去
// 等于把它交给沿途每一跳 —— 这正是旧协议的问题。
//
// 调用前 raw 必须已通过 ReturnURLAllowed（因此不含 query），这里直接用 ? 拼接。
func AppendTicketQuery(raw, ticket, state string) string {
	base := NormalizeReturnURL(raw)
	q := url.Values{}
	q.Set("oauth_ticket", ticket)
	q.Set("oauth_state", state)
	sep := "?"
	if strings.Contains(base, "?") {
		sep = "&"
	}
	return base + sep + q.Encode()
}
