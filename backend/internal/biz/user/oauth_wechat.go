package userbiz

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"unicode"

	"backend/model"
	"backend/rpc/pb/moe"
	"backend/utils"

	"github.com/spf13/viper"
	"gorm.io/gorm"
)

// WechatLogin 微信 OAuth 登录。
func WechatLogin(ctx context.Context, db *gorm.DB, in *moe.WechatLoginReq) (*moe.WechatLoginResp, error) {
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

	user, isNew, err := findOrCreateWechatUser(ctx, db, info)
	if err != nil {
		return nil, err
	}
	if _, err := utils.EnsureUserMoeNo(db, user.ID); err != nil {
		return nil, err
	}
	_ = db.WithContext(ctx).First(&user, user.ID).Error

	token, err := utils.GenerateToken(user.ID, user.Username)
	if err != nil {
		return nil, err
	}
	return &moe.WechatLoginResp{
		User:      ModelToProto(&user),
		Token:     token,
		IsNewUser: isNew,
	}, nil
}

// WechatAuthorizeURL 微信授权 URL。
func WechatAuthorizeURL(_ context.Context, in *moe.WechatAuthorizeURLReq) (*moe.WechatAuthorizeURLResp, error) {
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
	return &moe.WechatAuthorizeURLResp{AuthorizeUrl: url}, nil
}

func findOrCreateWechatUser(ctx context.Context, db *gorm.DB, info utils.WechatOAuthUserInfo) (model.User, bool, error) {
	openID := strings.TrimSpace(info.OpenID)
	var user model.User
	err := db.WithContext(ctx).Where("wechat_open_id = ?", openID).First(&user).Error
	if err == nil {
		applyWechatProfile(&user, info)
		if err := syncWechatUsername(ctx, db, &user, info); err != nil {
			return model.User{}, false, err
		}
		if err := db.WithContext(ctx).Save(&user).Error; err != nil {
			return model.User{}, false, err
		}
		return user, false, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return model.User{}, false, err
	}

	username, err := allocateWechatUsername(ctx, db, info.Nickname, openID, 0)
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
	if err := db.WithContext(ctx).Create(&user).Error; err != nil {
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

func syncWechatUsername(ctx context.Context, db *gorm.DB, user *model.User, info utils.WechatOAuthUserInfo) error {
	nickname := normalizeWechatDisplayName(info.Nickname)
	if nickname == "" || !isAutoWechatUsername(user.Username) {
		return nil
	}
	if user.Username == nickname {
		return nil
	}
	username, err := allocateWechatUsername(ctx, db, nickname, strings.TrimSpace(info.OpenID), user.ID)
	if err != nil {
		return err
	}
	user.Username = username
	return nil
}

func allocateWechatUsername(ctx context.Context, db *gorm.DB, nickname, openID string, excludeUserID uint) (string, error) {
	base := normalizeWechatDisplayName(nickname)
	if base == "" && len(openID) >= 6 {
		base = "wx_" + openID[len(openID)-6:]
	}
	if base == "" {
		base = "wechat_user"
	}
	candidate := base
	for i := 0; i < 8; i++ {
		var existing model.User
		err := db.WithContext(ctx).Where("username = ?", candidate).First(&existing).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return candidate, nil
		}
		if err != nil {
			return "", err
		}
		if excludeUserID > 0 && existing.ID == excludeUserID {
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
