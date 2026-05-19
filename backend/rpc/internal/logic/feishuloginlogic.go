package logic

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/logutil"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/spf13/viper"
	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type FeishuLoginLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewFeishuLoginLogic(ctx context.Context, svcCtx *svc.ServiceContext) *FeishuLoginLogic {
	return &FeishuLoginLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *FeishuLoginLogic) FeishuLogin(in *super.FeishuLoginReq) (*super.FeishuLoginResp, error) {
	if !viper.GetBool("feishu.enabled") {
		return nil, errorx.New(503, "飞书功能未启用")
	}
	info, err := utils.ExchangeFeishuOAuthCode(l.ctx, in.GetCode())
	if err != nil {
		l.Errorf("[认证] 飞书登录失败：换取用户信息 %v", err)
		return nil, errorx.New(401, "飞书授权失败，请重试")
	}
	if err := utils.TryEnsureFeishuDirectoryUser(l.ctx, info.Name, info.Email); err != nil {
		l.Infof("[认证] 飞书通讯录同步（可忽略）: %v", err)
	}

	user, isNew, err := l.findOrCreateFeishuUser(info)
	if err != nil {
		return nil, err
	}

	if _, err := utils.EnsureUserMoeNo(l.svcCtx.DB, user.ID); err != nil {
		l.Errorf("[认证] 飞书登录：补全 Moe 号失败 用户ID=%d 错误=%v", user.ID, err)
	}
	_ = l.svcCtx.DB.First(&user, user.ID).Error

	token, err := utils.GenerateToken(user.ID, user.Username)
	if err != nil {
		return nil, errorx.Internal("登录失败，请稍后重试")
	}

	l.Infof("[认证] 飞书登录成功 用户ID=%d 用户名=%s 新用户=%v open_id=%s 邮箱=%s",
		user.ID, user.Username, isNew, info.OpenID, logutil.MaskEmail(user.Email))

	return &super.FeishuLoginResp{
		User:      modelUserToProto(&user),
		Token:     token,
		IsNewUser: isNew,
	}, nil
}

func (l *FeishuLoginLogic) findOrCreateFeishuUser(info utils.FeishuOAuthUserInfo) (model.User, bool, error) {
	openID := strings.TrimSpace(info.OpenID)
	var user model.User
	err := l.svcCtx.DB.Where("feishu_open_id = ?", openID).First(&user).Error
	if err == nil {
		l.applyFeishuProfile(&user, info)
		if err := l.svcCtx.DB.Save(&user).Error; err != nil {
			return model.User{}, false, errorx.Internal("更新飞书资料失败")
		}
		return user, false, nil
	}
	if err != gorm.ErrRecordNotFound {
		return model.User{}, false, errorx.Internal("查询用户失败")
	}

	email := strings.TrimSpace(info.Email)
	if email != "" {
		if err := l.svcCtx.DB.Where("email = ?", email).First(&user).Error; err == nil {
			l.applyFeishuProfile(&user, info)
			if err := l.svcCtx.DB.Save(&user).Error; err != nil {
				return model.User{}, false, errorx.Internal("绑定飞书账号失败")
			}
			return user, false, nil
		} else if err != gorm.ErrRecordNotFound {
			return model.User{}, false, errorx.Internal("查询用户失败")
		}
	}

	username, err := l.allocateUsername(info.Name, email)
	if err != nil {
		return model.User{}, false, err
	}
	if email == "" {
		email = fmt.Sprintf("%s@feishu.oauth.local", openID)
	}
	avatar := strings.TrimSpace(info.Avatar)
	if avatar == "" {
		avatar = "https://picsum.photos/150"
	}

	openIDCopy := openID
	user = model.User{
		Username:     username,
		Password:     randomFeishuPassword(),
		Email:        email,
		Avatar:       avatar,
		FeishuOpenID: &openIDCopy,
	}
	l.applyFeishuProfile(&user, info)
	if err := l.svcCtx.DB.Create(&user).Error; err != nil {
		return model.User{}, false, errorx.Internal("注册失败，请稍后重试")
	}
	return user, true, nil
}

func (l *FeishuLoginLogic) applyFeishuProfile(user *model.User, info utils.FeishuOAuthUserInfo) {
	if strings.TrimSpace(info.Name) != "" {
		user.FeishuName = strings.TrimSpace(info.Name)
	}
	if email := strings.TrimSpace(info.Email); email != "" {
		if normalized, err := utils.NormalizeFeishuEmail(email); err == nil {
			user.FeishuEmail = normalized
		}
	}
	openID := strings.TrimSpace(info.OpenID)
	if openID != "" {
		openIDCopy := openID
		user.FeishuOpenID = &openIDCopy
	}
}

func (l *FeishuLoginLogic) allocateUsername(feishuName, email string) (string, error) {
	base := sanitizeFeishuUsername(feishuName)
	if base == "" && email != "" {
		if at := strings.Index(email, "@"); at > 0 {
			base = sanitizeFeishuUsername(email[:at])
		}
	}
	if base == "" {
		base = "feishu_user"
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

func sanitizeFeishuUsername(raw string) string {
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

func randomFeishuPassword() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func randomHex(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}
