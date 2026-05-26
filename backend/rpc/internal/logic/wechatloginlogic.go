package logic

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"strings"
	"unicode"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/spf13/viper"
	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type WechatLoginLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewWechatLoginLogic(ctx context.Context, svcCtx *svc.ServiceContext) *WechatLoginLogic {
	return &WechatLoginLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *WechatLoginLogic) WechatLogin(in *super.WechatLoginReq) (*super.WechatLoginResp, error) {
	if !viper.GetBool("wechat.enabled") {
		if !viper.IsSet("wechat.enabled") {
			return nil, errorx.New(503, "未配置微信登录：请在 config.yaml 添加 wechat 段（enabled: true）并重启 RPC")
		}
		return nil, errorx.New(503, "微信登录未启用")
	}
	flow := utils.NormalizeWechatOAuthFlow(in.GetFlow())
	if flow == "" {
		flow = "app"
	}
	info, err := utils.ExchangeWechatOAuthCode(l.ctx, in.GetCode(), flow)
	if err != nil {
		l.Errorf("[认证] 微信登录失败：换取用户信息 flow=%s %v", flow, err)
		msg := "微信授权失败，请重试"
		errText := err.Error()
		if strings.Contains(errText, "credentials missing") {
			msg = "服务端未配置微信移动应用凭证（config.yaml → wechat.app.app_id / app_secret）"
		} else if strings.Contains(errText, "10005") || strings.Contains(errText, "scope") {
			msg = "微信 AppID 与 scope 不匹配：请确认客户端与 VPS 均使用开放平台「移动应用」Moe Social Dev 凭证，且勿用公众号 AppID"
		} else if strings.Contains(errText, "wechat token api") {
			msg = "微信 code 无效或 AppID/Secret 不一致（请核对 VPS config.yaml 与 App 内 wechat_config.dart）"
		}
		return nil, errorx.New(401, msg)
	}

	user, isNew, err := l.findOrCreateWechatUser(info)
	if err != nil {
		return nil, err
	}

	if _, err := utils.EnsureUserMoeNo(l.svcCtx.DB, user.ID); err != nil {
		l.Errorf("[认证] 微信登录：补全 Moe 号失败 用户ID=%d 错误=%v", user.ID, err)
	}
	_ = l.svcCtx.DB.First(&user, user.ID).Error

	token, err := utils.GenerateToken(user.ID, user.Username)
	if err != nil {
		return nil, errorx.Internal("登录失败，请稍后重试")
	}

	l.Infof("[认证] 微信登录成功 用户ID=%d 用户名=%s 新用户=%v openid=%s",
		user.ID, user.Username, isNew, info.OpenID)

	return &super.WechatLoginResp{
		User:      modelUserToProto(&user),
		Token:     token,
		IsNewUser: isNew,
	}, nil
}

func (l *WechatLoginLogic) findOrCreateWechatUser(info utils.WechatOAuthUserInfo) (model.User, bool, error) {
	openID := strings.TrimSpace(info.OpenID)
	var user model.User
	err := l.svcCtx.DB.Where("wechat_open_id = ?", openID).First(&user).Error
	if err == nil {
		l.applyWechatProfile(&user, info)
		if err := l.syncWechatUsername(&user, info); err != nil {
			return model.User{}, false, err
		}
		if err := l.svcCtx.DB.Save(&user).Error; err != nil {
			return model.User{}, false, errorx.Internal("更新微信资料失败")
		}
		return user, false, nil
	}
	if err != gorm.ErrRecordNotFound {
		return model.User{}, false, errorx.Internal("查询用户失败")
	}

	username, err := l.allocateWechatUsername(info.Nickname, openID, 0)
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
		Password:     randomWechatPassword(),
		Email:        email,
		Avatar:       avatar,
		WechatOpenID: &openIDCopy,
	}
	l.applyWechatProfile(&user, info)
	if err := l.svcCtx.DB.Create(&user).Error; err != nil {
		return model.User{}, false, errorx.Internal("注册失败，请稍后重试")
	}
	return user, true, nil
}

func (l *WechatLoginLogic) applyWechatProfile(user *model.User, info utils.WechatOAuthUserInfo) {
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

func (l *WechatLoginLogic) syncWechatUsername(user *model.User, info utils.WechatOAuthUserInfo) error {
	nickname := normalizeWechatDisplayName(info.Nickname)
	if nickname == "" || !isAutoWechatUsername(user.Username) {
		return nil
	}
	if user.Username == nickname {
		return nil
	}
	username, err := l.allocateWechatUsername(nickname, strings.TrimSpace(info.OpenID), user.ID)
	if err != nil {
		return err
	}
	user.Username = username
	return nil
}

func (l *WechatLoginLogic) allocateWechatUsername(nickname, openID string, excludeUserID uint) (string, error) {
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
		err := l.svcCtx.DB.Where("username = ?", candidate).First(&existing).Error
		if err == gorm.ErrRecordNotFound {
			return candidate, nil
		}
		if err != nil {
			return "", errorx.Internal("检查用户名失败")
		}
		if excludeUserID > 0 && existing.ID == excludeUserID {
			return candidate, nil
		}
		suffix, _ := randomHex(3)
		candidate = fmt.Sprintf("%s_%s", truncateWechatRunes(base, 44), suffix)
	}
	return "", errorx.Internal("无法分配用户名")
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
	if strings.HasPrefix(u, "wx_") && len(u) <= 12 {
		return true
	}
	return false
}

func randomWechatPassword() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
