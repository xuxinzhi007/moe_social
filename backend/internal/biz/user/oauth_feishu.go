package userbiz

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/spf13/viper"
	"gorm.io/gorm"
)

// FeishuLogin OAuth 登录或注册。
func FeishuLogin(ctx context.Context, db *gorm.DB, in *super.FeishuLoginReq) (*super.FeishuLoginResp, error) {
	if !viper.GetBool("feishu.enabled") {
		return nil, ErrOAuthDisabled
	}
	info, err := utils.ExchangeFeishuOAuthCode(ctx, in.GetCode())
	if err != nil {
		return nil, fmt.Errorf("%w: 飞书授权失败，请重试", ErrUnauthorized)
	}
	_ = utils.TryEnsureFeishuDirectoryUser(ctx, info.Name, info.Email)

	user, isNew, err := findOrCreateFeishuUser(ctx, db, info)
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
	return &super.FeishuLoginResp{
		User:      ModelToProto(&user),
		Token:     token,
		IsNewUser: isNew,
	}, nil
}

// FeishuAuthorizeURL 生成飞书授权链接。
func FeishuAuthorizeURL(_ context.Context, in *super.FeishuAuthorizeURLReq) (*super.FeishuAuthorizeURLResp, error) {
	if !viper.GetBool("feishu.enabled") {
		return nil, ErrOAuthDisabled
	}
	url, err := utils.FeishuOAuthAuthorizeURL(in.GetState())
	if err != nil {
		return nil, ErrInvalidArgument
	}
	return &super.FeishuAuthorizeURLResp{AuthorizeUrl: url}, nil
}

// BindFeishu 绑定飞书邮箱。
func BindFeishu(ctx context.Context, db *gorm.DB, in *super.BindFeishuReq) (*super.BindFeishuResp, error) {
	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil || userID == 0 {
		return nil, ErrInvalidArgument
	}
	email, err := utils.NormalizeFeishuEmail(in.GetFeishuEmail())
	if err != nil {
		return nil, ErrInvalidArgument
	}
	var user model.User
	if err := db.WithContext(ctx).First(&user, uint(userID)).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	user.FeishuEmail = email
	if err := db.WithContext(ctx).Save(&user).Error; err != nil {
		return nil, err
	}
	return &super.BindFeishuResp{User: ModelToProto(&user)}, nil
}

// UnbindFeishu 解绑飞书邮箱。
func UnbindFeishu(ctx context.Context, db *gorm.DB, in *super.UnbindFeishuReq) (*super.UnbindFeishuResp, error) {
	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil || userID == 0 {
		return nil, ErrInvalidArgument
	}
	var user model.User
	if err := db.WithContext(ctx).First(&user, uint(userID)).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	user.FeishuEmail = ""
	if err := db.WithContext(ctx).Save(&user).Error; err != nil {
		return nil, err
	}
	return &super.UnbindFeishuResp{User: ModelToProto(&user)}, nil
}

// SendFeishuTestCard 发送飞书测试卡片。
func SendFeishuTestCard(ctx context.Context, db *gorm.DB, in *super.SendFeishuTestCardReq) (*super.SendFeishuTestCardResp, error) {
	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil || userID == 0 {
		return nil, ErrInvalidArgument
	}
	var user model.User
	if err := db.WithContext(ctx).Select("id", "feishu_email").First(&user, uint(userID)).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	target := strings.TrimSpace(user.FeishuEmail)
	if target == "" {
		return nil, ErrInvalidArgument
	}
	if err := utils.SendFeishuTestCard(ctx, target); err != nil {
		return nil, err
	}
	return &super.SendFeishuTestCardResp{}, nil
}

func findOrCreateFeishuUser(ctx context.Context, db *gorm.DB, info utils.FeishuOAuthUserInfo) (model.User, bool, error) {
	openID := strings.TrimSpace(info.OpenID)
	var user model.User
	err := db.WithContext(ctx).Where("feishu_open_id = ?", openID).First(&user).Error
	if err == nil {
		applyFeishuProfile(&user, info)
		if err := db.WithContext(ctx).Save(&user).Error; err != nil {
			return model.User{}, false, err
		}
		return user, false, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return model.User{}, false, err
	}

	email := strings.TrimSpace(info.Email)
	if email != "" {
		if err := db.WithContext(ctx).Where("email = ?", email).First(&user).Error; err == nil {
			applyFeishuProfile(&user, info)
			if err := db.WithContext(ctx).Save(&user).Error; err != nil {
				return model.User{}, false, err
			}
			return user, false, nil
		} else if !errors.Is(err, gorm.ErrRecordNotFound) {
			return model.User{}, false, err
		}
	}

	username, err := allocateFeishuUsername(ctx, db, info.Name, email)
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
		Password:     randomOAuthPassword(),
		Email:        email,
		Avatar:       avatar,
		FeishuOpenID: &openIDCopy,
	}
	applyFeishuProfile(&user, info)
	if err := db.WithContext(ctx).Create(&user).Error; err != nil {
		return model.User{}, false, err
	}
	return user, true, nil
}

func applyFeishuProfile(user *model.User, info utils.FeishuOAuthUserInfo) {
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

func allocateFeishuUsername(ctx context.Context, db *gorm.DB, feishuName, email string) (string, error) {
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
		err := db.WithContext(ctx).Where("username = ?", candidate).First(&existing).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return candidate, nil
		}
		if err != nil {
			return "", err
		}
		suffix, _ := randomOAuthHex(3)
		candidate = fmt.Sprintf("%s_%s", base, suffix)
	}
	return "", fmt.Errorf("无法分配用户名")
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

func randomOAuthPassword() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func randomOAuthHex(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}
