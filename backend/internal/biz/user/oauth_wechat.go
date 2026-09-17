package userbiz

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"unicode"

	userv1 "backend/api/user/v1"
	"backend/internal/oauthflow"
	"backend/model"
	"backend/pkg/conf"
	"backend/utils"

	"gorm.io/gorm"
)

// WechatLogin 微信 OAuth 登录。
//
// 两条互斥的通路，取决于授权是怎么发起的：
//
//   - 浏览器 flow（website / mp）：供应商回调到服务端，服务端把授权码封存进一次性
//     ticket 再 302 回客户端。客户端提交 ticket + code_verifier，**不许自带 code**。
//   - 原生 SDK flow（app）：微信 SDK 在进程内直接返回 code，没有浏览器回调，
//     也就没有 ticket。客户端提交 WechatAuthorizeURL(flow=app) 拿到的 state、
//     SDK 给的 code 和 code_verifier。
//
// 供应商 flow 一律以服务端事务里记录的值为准，不采信请求里的 flow 字段 ——
// 否则调用方声称 flow=app 就能绕过回跳白名单与 ticket 绑定。
func WechatLogin(ctx context.Context, store UserStore, txs *oauthflow.Store, in *userv1.WechatLoginReq) (*userv1.WechatLoginResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	if !conf.Get().Wechat.Enabled {
		if !conf.IsSet("wechat.enabled") {
			return nil, fmt.Errorf("%w: 未配置微信登录", ErrOAuthDisabled)
		}
		return nil, ErrOAuthDisabled
	}

	code, flow, err := resolveWechatLoginCredential(txs, in)
	if err != nil {
		return nil, err
	}

	info, err := utils.ExchangeWechatOAuthCode(ctx, code, flow)
	if err != nil {
		msg := "微信授权失败，请重试"
		errText := err.Error()
		if strings.Contains(errText, "凭证缺失") {
			msg = "服务端未配置微信移动应用凭证"
		}
		return nil, fmt.Errorf("%w: %s", ErrUnauthorized, msg)
	}

	user, isNew, err := findOrCreateWechatUser(ctx, store, info)
	if err != nil {
		return nil, err
	}
	if _, err := utils.EnsureUserMoeNo(store.Raw(), user.ID); err != nil {
		return nil, err
	}
	user, _ = store.ReloadUser(ctx, user.ID)

	token, err := utils.GenerateToken(user.ID, user.Username)
	if err != nil {
		return nil, err
	}
	return &userv1.WechatLoginResp{
		User:      ModelToUserV1(&user),
		Token:     token,
		IsNewUser: isNew,
	}, nil
}

// resolveWechatLoginCredential 消费授权事务并返回（供应商授权码、服务端记录的 flow）。
//
// ticket 与 state 必须恰好提供一个：都给或都不给都说明调用方没搞清新协议，
// 与其猜一个不如明确拒绝。两个分支都是「取出即作废」，verifier 比对失败也不会
// 把凭证还回去，因此拿同一个 ticket/state 反复试 verifier 只有第一次有机会。
func resolveWechatLoginCredential(txs *oauthflow.Store, in *userv1.WechatLoginReq) (string, string, error) {
	ticket := strings.TrimSpace(in.GetTicket())
	state := strings.TrimSpace(in.GetState())
	code := strings.TrimSpace(in.GetCode())
	verifier := in.GetCodeVerifier()

	switch {
	case ticket != "" && state != "":
		return "", "", ErrInvalidArgument
	case ticket != "":
		if code != "" {
			// 浏览器 flow 的授权码只该存在于服务端 ticket 里；客户端还能拿出一个 code，
			// 说明它走的是旧协议或试图注入别人的授权码。
			return "", "", errLegacyOAuthCodeOnly
		}
		tk, err := txs.ConsumeTicket(ticket, verifier)
		if err != nil {
			return "", "", mapOAuthFlowError(err)
		}
		if tk.Provider != oauthflow.ProviderWechat || tk.Flow == "app" {
			// app flow 不经过浏览器回调，不可能有 ticket。
			return "", "", mapOAuthFlowError(oauthflow.ErrTicketUnknown)
		}
		return tk.Code, tk.Flow, nil
	case state != "":
		if code == "" {
			return "", "", ErrInvalidArgument
		}
		tx, err := txs.ConsumeStateWithVerifier(state, verifier)
		if err != nil {
			return "", "", mapOAuthFlowError(err)
		}
		if tx.Provider != oauthflow.ProviderWechat || tx.Flow != "app" {
			// 只有原生 SDK flow 才允许直接提交 code；浏览器 flow 必须走 ticket。
			return "", "", errLegacyOAuthCodeOnly
		}
		return code, tx.Flow, nil
	default:
		return "", "", errLegacyOAuthCodeOnly
	}
}

// WechatAuthorizeURL 微信授权 URL。
//
// flow=app 时不下发授权页地址（原生 SDK 自己唤起微信），只签发一个绑定了
// code_challenge 的 state；website / mp 走浏览器，state 同样由服务端生成，
// 请求里的旧 state 字段被完全忽略（它曾是回跳地址，是开放重定向的根源）。
func WechatAuthorizeURL(_ context.Context, txs *oauthflow.Store, in *userv1.WechatAuthorizeURLReq) (*userv1.WechatAuthorizeURLResp, error) {
	if !conf.Get().Wechat.Enabled {
		if !conf.IsSet("wechat.enabled") {
			return nil, fmt.Errorf("%w: 未配置微信登录", ErrOAuthDisabled)
		}
		return nil, ErrOAuthDisabled
	}
	flow := utils.NormalizeWechatOAuthFlow(in.GetFlow())
	if flow == "" {
		flow = "website"
	}
	tx, err := txs.BeginAuth(oauthflow.ProviderWechat, flow, in.GetReturnUrl(), in.GetCodeChallenge())
	if err != nil {
		return nil, mapOAuthFlowError(err)
	}
	if flow == "app" {
		return &userv1.WechatAuthorizeURLResp{State: tx.State}, nil
	}
	url, err := utils.WechatOAuthAuthorizeURLForFlow(tx.State, flow)
	if err != nil {
		return nil, ErrInvalidArgument
	}
	return &userv1.WechatAuthorizeURLResp{AuthorizeUrl: url, State: tx.State}, nil
}

func findOrCreateWechatUser(ctx context.Context, store UserStore, info utils.WechatOAuthUserInfo) (model.User, bool, error) {
	openID := strings.TrimSpace(info.OpenID)
	user, err := store.FindUserByWechatOpenID(ctx, openID)
	if err == nil {
		applyWechatProfile(&user, info)
		if err := syncWechatUsername(ctx, store, &user, info); err != nil {
			return model.User{}, false, err
		}
		if err := store.SaveUser(ctx, &user); err != nil {
			return model.User{}, false, err
		}
		return user, false, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return model.User{}, false, err
	}

	username, err := allocateWechatUsername(ctx, store, info.Nickname, openID, 0)
	if err != nil {
		return model.User{}, false, err
	}
	email := fmt.Sprintf("%s@wechat.oauth.local", openID)
	avatar := strings.TrimSpace(info.Avatar)
	if avatar == "" {
		avatar = "https://picsum.photos/150"
	}
	openIDCopy := openID
	user = model.User{
		Username:     username,
		Password:     randomOAuthPassword(),
		Email:        email,
		Avatar:       avatar,
		WechatOpenID: &openIDCopy,
	}
	applyWechatProfile(&user, info)
	if err := store.CreateUser(ctx, &user); err != nil {
		return model.User{}, false, err
	}
	return user, true, nil
}

func applyWechatProfile(user *model.User, info utils.WechatOAuthUserInfo) {
	if name := strings.TrimSpace(info.Nickname); name != "" {
		user.WechatNickname = name
	}
	if u := strings.TrimSpace(info.UnionID); u != "" {
		user.WechatUnionID = u
	}
	openID := strings.TrimSpace(info.OpenID)
	if openID != "" {
		openIDCopy := openID
		user.WechatOpenID = &openIDCopy
	}
	if avatar := strings.TrimSpace(info.Avatar); avatar != "" {
		user.Avatar = avatar
	}
}

func syncWechatUsername(ctx context.Context, store UserStore, user *model.User, info utils.WechatOAuthUserInfo) error {
	nickname := normalizeWechatDisplayName(info.Nickname)
	if nickname == "" || !isAutoWechatUsername(user.Username) {
		return nil
	}
	if user.Username == nickname {
		return nil
	}
	username, err := allocateWechatUsername(ctx, store, nickname, strings.TrimSpace(info.OpenID), user.ID)
	if err != nil {
		return err
	}
	user.Username = username
	return nil
}

func allocateWechatUsername(ctx context.Context, store UserStore, nickname, openID string, excludeUserID uint) (string, error) {
	base := normalizeWechatDisplayName(nickname)
	if base == "" && len(openID) >= 6 {
		base = "wx_" + openID[len(openID)-6:]
	}
	if base == "" {
		base = "wechat_user"
	}
	candidate := base
	for i := 0; i < 8; i++ {
		taken, err := store.UsernameTakenExcept(ctx, candidate, excludeUserID)
		if err != nil {
			return "", err
		}
		if !taken {
			return candidate, nil
		}
		suffix, _ := randomOAuthHex(3)
		candidate = fmt.Sprintf("%s_%s", truncateWechatRunes(base, 44), suffix)
	}
	return "", fmt.Errorf("无法分配用户名")
}

func normalizeWechatDisplayName(raw string) string {
	raw = strings.TrimSpace(raw)
	var b strings.Builder
	for _, r := range raw {
		if r == 0 || unicode.IsControl(r) {
			continue
		}
		b.WriteRune(r)
	}
	return truncateWechatRunes(strings.TrimSpace(b.String()), 50)
}

func truncateWechatRunes(raw string, max int) string {
	if max <= 0 {
		return ""
	}
	rs := []rune(raw)
	if len(rs) <= max {
		return raw
	}
	return string(rs[:max])
}

func isAutoWechatUsername(username string) bool {
	u := strings.TrimSpace(username)
	if u == "" {
		return true
	}
	if strings.HasPrefix(u, "wechat_user") {
		return true
	}
	return strings.HasPrefix(u, "wx_") && len(u) <= 12
}
