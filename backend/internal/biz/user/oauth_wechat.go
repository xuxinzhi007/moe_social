package userbiz

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"unicode"

	userv1 "backend/api/user/v1"
	"backend/model"
	"backend/utils"

	"github.com/spf13/viper"
	"gorm.io/gorm"
)

// WechatLogin 微信 OAuth 登录。
func WechatLogin(ctx context.Context, store UserStore, in *userv1.WechatLoginReq) (*userv1.WechatLoginResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	if !viper.GetBool("wechat.enabled") {
		if !viper.IsSet("wechat.enabled") {
			return nil, fmt.Errorf("%w: 未配置微信登录", ErrOAuthDisabled)
		}
		return nil, ErrOAuthDisabled
	}
	flow := utils.NormalizeWechatOAuthFlow(in.GetFlow())
	if flow == "" {
		flow = "app"
	}
	info, err := utils.ExchangeWechatOAuthCode(ctx, in.GetCode(), flow)
	if err != nil {
		msg := "微信授权失败，请重试"
		errText := err.Error()
		if strings.Contains(errText, "credentials missing") {
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

// WechatAuthorizeURL 微信授权 URL。
func WechatAuthorizeURL(_ context.Context, in *userv1.WechatAuthorizeURLReq) (*userv1.WechatAuthorizeURLResp, error) {
	if !viper.GetBool("wechat.enabled") {
		if !viper.IsSet("wechat.enabled") {
			return nil, fmt.Errorf("%w: 未配置微信登录", ErrOAuthDisabled)
		}
		return nil, ErrOAuthDisabled
	}
	flow := utils.NormalizeWechatOAuthFlow(in.GetFlow())
	if flow == "" {
		flow = "website"
	}
	url, err := utils.WechatOAuthAuthorizeURLForFlow(in.GetState(), flow)
	if err != nil {
		return nil, ErrInvalidArgument
	}
	return &userv1.WechatAuthorizeURLResp{AuthorizeUrl: url}, nil
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
