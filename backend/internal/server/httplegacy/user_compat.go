package httplegacy

import (
	"backend/internal/platform/svc"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeUserCompatRoutes OAuth 回调（不走 proto HTTP）。
const PilotNativeUserCompatRoutes = 2

// RegisterUserCompat P1：用户社交/VIP 已迁入 RegisterUserServiceHTTPServer / RegisterVipServiceHTTPServer。
func RegisterUserCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/api/auth/feishu/callback", userFeishuOAuthCallback())
	r.GET("/api/auth/wechat/callback", userWechatOAuthCallback())
	_ = svcCtx
}
