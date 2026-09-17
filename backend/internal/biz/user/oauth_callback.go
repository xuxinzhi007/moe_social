package userbiz

import (
	"fmt"
	"html"
	"net/http"
	"strings"

	"backend/internal/oauthflow"
	"backend/utils"
)

// FeishuOAuthCallbackInput 飞书 OAuth redirect 参数。
type FeishuOAuthCallbackInput struct {
	Code  string
	State string
}

// WechatOAuthCallbackInput 微信 OAuth redirect 参数。
type WechatOAuthCallbackInput struct {
	Code  string
	State string
}

// HandleFeishuOAuthCallback 飞书 redirect_uri 落点。
func HandleFeishuOAuthCallback(w http.ResponseWriter, r *http.Request, in FeishuOAuthCallbackInput) {
	handleOAuthCallback(w, r, oauthflow.Default(), oauthflow.ProviderFeishu, in.Code, in.State)
}

// HandleWechatOAuthCallback 微信 redirect_uri 落点。
func HandleWechatOAuthCallback(w http.ResponseWriter, r *http.Request, in WechatOAuthCallbackInput) {
	handleOAuthCallback(w, r, oauthflow.Default(), oauthflow.ProviderWechat, in.Code, in.State)
}

// handleOAuthCallback 消费服务端 state，把供应商授权码封存成一次性 ticket，
// 再 302 回客户端登记的白名单地址。
//
// 三条不可退让的规则（都是 #50 修掉的洞）：
//  1. 回跳目标只能来自授权事务里那份**已通过白名单校验**的地址，绝不取自本次请求参数 ——
//     旧协议把 state 当回跳地址，攻击者填自己的站点就能收走别人的授权码。
//  2. 回跳 URL 只带 oauth_ticket / oauth_state，**不带授权码**。地址栏、浏览器历史、
//     Referer、沿途代理日志都会留下 URL，把 code 放进去等于交给每一跳。
//  3. 失败页不展示 code。旧实现有一行 `<p>code=%s</p>`，把授权码直接印在页面上。
//
// state 取出即删除：浏览器预取、用户刷新、攻击者重放都只有第一次能成功。
func handleOAuthCallback(w http.ResponseWriter, r *http.Request, txs *oauthflow.Store, provider, code, state string) {
	label := oauthProviderLabel(provider)

	// ticket 是一次性的，被任何中间层缓存住都会让用户第二次访问拿到废票。
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Pragma", "no-cache")
	// 回跳到客户端页面时，别把带 state 的供应商回调地址泄露进 Referer。
	w.Header().Set("Referrer-Policy", "no-referrer")

	code = strings.TrimSpace(code)
	state = strings.TrimSpace(state)
	if code == "" || state == "" {
		// 用户在供应商页面点了取消（供应商只带 error 不带 code），或参数被截断。
		writeOAuthFailurePage(w, label, http.StatusBadRequest, "授权未完成或已取消。")
		return
	}

	tx, err := txs.ConsumeState(state)
	if err != nil {
		writeOAuthFailurePage(w, label, http.StatusBadRequest, "授权已失效，请返回 Moe Social 重新登录。")
		return
	}
	if tx.Provider != provider {
		// 拿飞书的事务走微信回调（或反之）：一律按失效处理，不解释差异，免得变成探测接口。
		writeOAuthFailurePage(w, label, http.StatusBadRequest, "授权已失效，请返回 Moe Social 重新登录。")
		return
	}
	if tx.ReturnURL == "" {
		// 原生 SDK flow 的事务不会走到浏览器回调；真走到了说明配置或调用方有问题。
		// 明确告知，但**不展示 code** —— 票据没发出去，code 就地作废。
		writeOAuthFailurePage(w, label, http.StatusInternalServerError,
			"授权成功，但这次登录没有登记回跳地址，无法自动返回 App。")
		return
	}

	ticket, err := txs.IssueTicket(tx, code)
	if err != nil {
		writeOAuthFailurePage(w, label, http.StatusInternalServerError, "授权票据签发失败，请重新登录。")
		return
	}
	http.Redirect(w, r, oauthflow.AppendTicketQuery(tx.ReturnURL, ticket, tx.State), http.StatusFound)
}

func oauthProviderLabel(provider string) string {
	if provider == oauthflow.ProviderWechat {
		return "微信授权"
	}
	return "飞书授权"
}

// writeOAuthFailurePage 输出失败页。
//
// 文案是固定的几句，不含 code、state、ticket 或任何内部错误细节：
// 这个端点公开可达，页面内容会进浏览器历史，也会被供应商的 WebView 截图上传。
func writeOAuthFailurePage(w http.ResponseWriter, label string, status int, message string) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	_, _ = fmt.Fprintf(w, `<!DOCTYPE html><html><head><meta charset="utf-8">
<meta name="referrer" content="no-referrer">
<title>%s</title></head><body>
<p>%s</p>
<p style="font-size:12px;color:#666">请返回 Moe Social 重新发起登录。出于安全考虑，本页不会显示授权码。</p>
</body></html>`, html.EscapeString(label), html.EscapeString(message))
}

// RefreshAccessToken 用有效 JWT 换取新 token。
func RefreshAccessToken(authHeader string) (string, error) {
	auth := strings.TrimSpace(authHeader)
	if auth == "" {
		return "", ErrMissingAuthorization
	}
	parts := strings.SplitN(auth, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		return "", ErrInvalidAuthorizationFormat
	}
	tokenStr := strings.TrimSpace(parts[1])
	if tokenStr == "" {
		return "", ErrMissingToken
	}
	claims, err := utils.ParseToken(tokenStr)
	if err != nil {
		return "", ErrInvalidToken
	}
	return utils.GenerateToken(claims.UserID, claims.Username)
}
