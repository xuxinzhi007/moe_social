// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package user

import (
	"context"
	"fmt"
	"html"
	"net/http"
	"strings"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type FeishuOAuthCallbackLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewFeishuOAuthCallbackLogic(ctx context.Context, svcCtx *svc.ServiceContext) *FeishuOAuthCallbackLogic {
	return &FeishuOAuthCallbackLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

// FeishuOAuthCallback 飞书 redirect_uri 落点；带 code 时跳回 App（state=客户端 origin）。
func (l *FeishuOAuthCallbackLogic) FeishuOAuthCallback(
	w http.ResponseWriter,
	r *http.Request,
	req *types.FeishuOAuthCallbackReq,
) error {
	code := strings.TrimSpace(req.Code)
	if code == "" {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write([]byte(`<!DOCTYPE html><html><body><p>飞书授权未完成或已取消。</p></body></html>`))
		return nil
	}
	state := strings.TrimSpace(req.State)
	if returnURL := utils.BuildFeishuOAuthReturnURL(state, code); returnURL != "" {
		http.Redirect(w, r, returnURL, http.StatusFound)
		return nil
	}
	if state == "moe_app" {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write([]byte(`<!DOCTYPE html><html><head><meta charset="utf-8"><title>飞书授权</title></head>
<body><p>授权成功，请返回 App…</p></body></html>`))
		return nil
	}
	escaped := html.EscapeString(code)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = fmt.Fprintf(w, `<!DOCTYPE html><html><head><meta charset="utf-8"><title>飞书授权</title>
<meta http-equiv="refresh" content="2;url=about:blank"></head><body>
<p>授权成功。请返回 Moe Social App 完成登录。</p>
<p style="font-size:12px;color:#666">code=%s</p>
<p style="font-size:12px;color:#999">未配置 feishu.app_return_url 且 state 非 http(s) 地址，无法自动跳回。</p>
</body></html>`, escaped)
	return nil
}
