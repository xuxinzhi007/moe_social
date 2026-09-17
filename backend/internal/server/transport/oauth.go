package transport

import (
	userbiz "backend/internal/biz/user"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterOAuth 注册两个供应商回调路由（GET）。导出是为了让 HTTP 级测试
// 能挂上真正生产用的这两条路由，而不是在测试里抄一遍路径与参数解析。
func RegisterOAuth(r *khttp.Router) {
	r.GET("/api/auth/feishu/callback", feishuOAuthCallback())
	r.GET("/api/auth/wechat/callback", wechatOAuthCallback())
}

// 回调参数一律从查询串直接取，不能用 ctx.Bind：
// 它走的是 body 解码器，而浏览器重定向过来的 GET 没有 Content-Type，
// Kratos 的 DefaultRequestDecoder 会直接回 400 CODEC「unregister Content-Type: 」，
// 回调逻辑根本执行不到（实测）。也不能换 ctx.BindQuery —— 那个认 json tag，
// 而 types.FeishuOAuthCallbackReq 这些 legacy 结构体只有 go-zero 时代的 form tag。
func feishuOAuthCallback() func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		q := ctx.Request().URL.Query()
		userbiz.HandleFeishuOAuthCallback(ctx.Response(), ctx.Request(), userbiz.FeishuOAuthCallbackInput{
			Code: q.Get("code"), State: q.Get("state"),
		})
		return nil
	}
}

func wechatOAuthCallback() func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		q := ctx.Request().URL.Query()
		userbiz.HandleWechatOAuthCallback(ctx.Response(), ctx.Request(), userbiz.WechatOAuthCallbackInput{
			Code: q.Get("code"), State: q.Get("state"),
		})
		return nil
	}
}
