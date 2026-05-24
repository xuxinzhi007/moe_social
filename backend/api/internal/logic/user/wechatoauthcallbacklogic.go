// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

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

type WechatOAuthCallbackLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewWechatOAuthCallbackLogic(ctx context.Context, svcCtx *svc.ServiceContext) *WechatOAuthCallbackLogic {
	return &WechatOAuthCallbackLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

// WechatOAuthCallback 公众号 redirect_uri；带 code 时跳回 Web/App（state=客户端 origin 或深链）。
func (l *WechatOAuthCallbackLogic) WechatOAuthCallback(
	w http.ResponseWriter,
	r *http.Request,
	req *types.WechatOAuthCallbackReq,
) error {
	code := strings.TrimSpace(req.Code)
	if code == "" {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write([]byte(`<!DOCTYPE html><html><body><p>微信授权未完成或已取消。</p><p style="font-size:12px;color:#666">公众号网页授权请在微信内打开登录页后重试。</p></body></html>`))
		return nil
	}
	state := strings.TrimSpace(req.State)
	if returnURL := utils.BuildWechatOAuthReturnURL(state, code); returnURL != "" {
		http.Redirect(w, r, returnURL, http.StatusFound)
		return nil
	}
	escaped := html.EscapeString(code)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = fmt.Fprintf(w, `<!DOCTYPE html><html><head><meta charset="utf-8"><title>微信授权</title></head><body>
<p>授权成功。请返回 Moe Social 完成登录。</p>
<p style="font-size:12px;color:#666">code=%s</p>
<p style="font-size:12px;color:#999">未配置 wechat.app_return_url 且 state 非有效回跳地址。</p>
</body></html>`, escaped)
	return nil
}
