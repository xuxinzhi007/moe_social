package httplegacy

import (
	"errors"
	"net/http"

	userbiz "backend/internal/biz/user"
	"backend/internal/legacy/types"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func userFeishuOAuthCallback() func(khttp.Context) error {
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

func userWechatOAuthCallback() func(khttp.Context) error {
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

func userRefreshToken() func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		tok, err := userbiz.RefreshAccessToken(ctx.Request().Header.Get("Authorization"))
		if err != nil {
			switch {
			case errors.Is(err, userbiz.ErrMissingAuthorization):
				return ctx.JSON(http.StatusUnauthorized, types.BaseResp{Code: 401, Message: "缺少 Authorization", Success: false})
			case errors.Is(err, userbiz.ErrInvalidAuthorizationFormat):
				return ctx.JSON(http.StatusUnauthorized, types.BaseResp{Code: 401, Message: "Authorization 格式应为 Bearer <token>", Success: false})
			case errors.Is(err, userbiz.ErrMissingToken):
				return ctx.JSON(http.StatusUnauthorized, types.BaseResp{Code: 401, Message: "缺少 token", Success: false})
			default:
				return ctx.JSON(http.StatusUnauthorized, types.BaseResp{Code: 401, Message: "令牌无效或已过期", Success: false})
			}
		}
		return ctx.JSON(http.StatusOK, types.RefreshTokenResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data:     types.RefreshTokenData{Token: tok},
		})
	}
}
