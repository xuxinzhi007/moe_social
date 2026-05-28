package userbiz

import (
	"fmt"
	"html"
	"net/http"
	"strings"

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
	code := strings.TrimSpace(in.Code)
	if code == "" {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write([]byte(`<!DOCTYPE html><html><body><p>飞书授权未完成或已取消。</p></body></html>`))
		return
	}
	state := strings.TrimSpace(in.State)
	if returnURL := utils.BuildFeishuOAuthReturnURL(state, code); returnURL != "" {
		http.Redirect(w, r, returnURL, http.StatusFound)
		return
	}
	if state == "moe_app" {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write([]byte(`<!DOCTYPE html><html><head><meta charset="utf-8"><title>飞书授权</title></head>
<body><p>授权成功，请返回 App…</p></body></html>`))
		return
	}
	escaped := html.EscapeString(code)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = fmt.Fprintf(w, `<!DOCTYPE html><html><head><meta charset="utf-8"><title>飞书授权</title>
<meta http-equiv="refresh" content="2;url=about:blank"></head><body>
<p>授权成功。请返回 Moe Social App 完成登录。</p>
<p style="font-size:12px;color:#666">code=%s</p>
<p style="font-size:12px;color:#999">未配置 feishu.app_return_url 且 state 非 http(s) 地址，无法自动跳回。</p>
</body></html>`, escaped)
}

// HandleWechatOAuthCallback 微信公众号 redirect_uri 落点。
func HandleWechatOAuthCallback(w http.ResponseWriter, r *http.Request, in WechatOAuthCallbackInput) {
	code := strings.TrimSpace(in.Code)
	if code == "" {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write([]byte(`<!DOCTYPE html><html><body><p>微信授权未完成或已取消。</p><p style="font-size:12px;color:#666">公众号网页授权请在微信内打开登录页后重试。</p></body></html>`))
		return
	}
	state := strings.TrimSpace(in.State)
	if returnURL := utils.BuildWechatOAuthReturnURL(state, code); returnURL != "" {
		http.Redirect(w, r, returnURL, http.StatusFound)
		return
	}
	escaped := html.EscapeString(code)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = fmt.Fprintf(w, `<!DOCTYPE html><html><head><meta charset="utf-8"><title>微信授权</title></head><body>
<p>授权成功。请返回 Moe Social 完成登录。</p>
<p style="font-size:12px;color:#666">code=%s</p>
<p style="font-size:12px;color:#999">未配置 wechat.app_return_url 且 state 非有效回跳地址。</p>
</body></html>`, escaped)
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
