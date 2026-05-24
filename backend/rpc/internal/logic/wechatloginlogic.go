package logic

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"strings"

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
			msg = "服务端未配置微信 AppID/Secret（wechat.app 或 wechat.mp）"
		} else if strings.Contains(errText, "wechat token api") {
			msg = "微信拒绝授权：AppID/包名/签名与开放平台移动应用不一致"
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
		if err := l.svcCtx.DB.Save(&user).Error; err != nil {
			return model.User{}, false, errorx.Internal("更新微信资料失败")
		}
		return user, false, nil
	}
	if err != gorm.ErrRecordNotFound {
		return model.User{}, false, errorx.Internal("查询用户失败")
	}

	username, err := l.allocateWechatUsername(info.Nickname, openID)
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

func (l *WechatLoginLogic) allocateWechatUsername(nickname, openID string) (string, error) {
	base := sanitizeWechatUsername(nickname)
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
		suffix, _ := randomHex(3)
		candidate = fmt.Sprintf("%s_%s", base, suffix)
	}
	return "", errorx.Internal("无法分配用户名")
}

func sanitizeWechatUsername(raw string) string {
	raw = strings.TrimSpace(raw)
	var b strings.Builder
	for _, r := range raw {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '_' {
			b.WriteRune(r)
		}
	}
	s := b.String()
	if len(s) > 20 {
		s = s[:20]
	}
	return s
}

func randomWechatPassword() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
