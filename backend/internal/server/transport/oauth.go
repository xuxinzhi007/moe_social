package transport

import (
	userbiz "backend/internal/biz/user"
	"backend/internal/legacy/types"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func registerOAuth(r *khttp.Router) {
	r.GET("/api/auth/feishu/callback", feishuOAuthCallback())
	r.GET("/api/auth/wechat/callback", wechatOAuthCallback())
}

func feishuOAuthCallback() func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.FeishuOAuthCallbackReq
		if err := bindRequest(ctx, &req); err != nil {
			return err
		}
		userbiz.HandleFeishuOAuthCallback(ctx.Response(), ctx.Request(), userbiz.FeishuOAuthCallbackInput{
			Code: req.Code, State: req.State,
		})
		return nil
	}
}

func wechatOAuthCallback() func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.WechatOAuthCallbackReq
		if err := bindRequest(ctx, &req); err != nil {
			return err
		}
		userbiz.HandleWechatOAuthCallback(ctx.Response(), ctx.Request(), userbiz.WechatOAuthCallbackInput{
			Code: req.Code, State: req.State,
		})
		return nil
	}
}
