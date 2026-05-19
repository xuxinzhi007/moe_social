package user

import (
	"fmt"
	"html"
	"net/http"
	"strings"

	"backend/api/internal/logic/user"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func FeishuAuthorizeURLHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		state := strings.TrimSpace(r.URL.Query().Get("state"))
		l := user.NewFeishuAuthLogic(r.Context(), svcCtx)
		resp, err := l.AuthorizeURL(state)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}

func FeishuLoginHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.FeishuLoginReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		l := user.NewFeishuAuthLogic(r.Context(), svcCtx)
		resp, err := l.Login(strings.TrimSpace(req.Code))
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}
		httpx.OkJsonCtx(r.Context(), w, resp)
	}
}

// FeishuOAuthCallbackHandler 飞书 redirect_uri 落点；带 code 时跳回 App（state=客户端 origin）。
func FeishuOAuthCallbackHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		code := strings.TrimSpace(r.URL.Query().Get("code"))
		if code == "" {
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			_, _ = w.Write([]byte(`<!DOCTYPE html><html><body><p>飞书授权未完成或已取消。</p></body></html>`))
			return
		}
		state := strings.TrimSpace(r.URL.Query().Get("state"))
		// App WebView：state=moe_app，不 302，由客户端拦截 code 后关页；仅 Web 跳回 origin。
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
}
