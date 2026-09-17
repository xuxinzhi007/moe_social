package userbiz

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strconv"
	"strings"

	userv1 "backend/api/user/v1"
	"backend/internal/oauthflow"
	"backend/model"
	"backend/pkg/conf"
	"backend/utils"

	"gorm.io/gorm"
)

// FeishuLogin OAuth 登录或注册。
//
// 只接受回调签发的一次性 ticket 加客户端本地保管的 code_verifier；授权码本身
// 由服务端在回调时封存进 ticket，客户端从头到尾拿不到它。旧的「直接提交 code」
// 通路已关闭 —— 那条路上任何截获到回跳 URL 的人都能登录成别人。
func FeishuLogin(ctx context.Context, store UserStore, txs *oauthflow.Store, in *userv1.FeishuLoginReq) (*userv1.FeishuLoginResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	if !conf.Get().Feishu.Enabled {
		return nil, ErrOAuthDisabled
	}
	if strings.TrimSpace(in.GetCode()) != "" {
		return nil, errLegacyOAuthCodeOnly
	}
	ticket, err := txs.ConsumeTicket(in.GetTicket(), in.GetCodeVerifier())
	if err != nil {
		return nil, mapOAuthFlowError(err)
	}
	if ticket.Provider != oauthflow.ProviderFeishu {
		return nil, mapOAuthFlowError(oauthflow.ErrTicketUnknown)
	}

	info, err := utils.ExchangeFeishuOAuthCode(ctx, ticket.Code)
	if err != nil {
		return nil, fmt.Errorf("%w: 飞书授权失败，请重试", ErrUnauthorized)
	}
	_ = utils.TryEnsureFeishuDirectoryUser(ctx, info.Name, info.Email)

	user, isNew, err := findOrCreateFeishuUser(ctx, store, info)
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
	return &userv1.FeishuLoginResp{
		User:      ModelToUserV1(&user),
		Token:     token,
		IsNewUser: isNew,
	}, nil
}

// FeishuAuthorizeURL 生成飞书授权链接，并登记服务端授权事务。
//
// 请求里的 state 字段被**完全忽略**：旧协议拿它当回跳地址，是开放重定向的根源。
// 回跳地址改由 return_url 提供并须精确命中白名单，state 换成服务端生成的随机串，
// 与 return_url / code_challenge / 供应商配置身份 / 期限一起存在服务端事务里。
func FeishuAuthorizeURL(_ context.Context, txs *oauthflow.Store, in *userv1.FeishuAuthorizeURLReq) (*userv1.FeishuAuthorizeURLResp, error) {
	if !conf.Get().Feishu.Enabled {
		return nil, ErrOAuthDisabled
	}
	tx, err := txs.BeginAuth(oauthflow.ProviderFeishu, "", in.GetReturnUrl(), in.GetCodeChallenge())
	if err != nil {
		return nil, mapOAuthFlowError(err)
	}
	url, err := utils.FeishuOAuthAuthorizeURL(tx.State)
	if err != nil {
		return nil, ErrInvalidArgument
	}
	return &userv1.FeishuAuthorizeURLResp{AuthorizeUrl: url, State: tx.State}, nil
}

// BindFeishu 绑定飞书邮箱。
func BindFeishu(ctx context.Context, store UserStore, in *userv1.BindFeishuReq) (*userv1.BindFeishuResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil || userID == 0 {
		return nil, ErrInvalidArgument
	}
	email, err := utils.NormalizeFeishuEmail(in.GetFeishuEmail())
	if err != nil {
		return nil, ErrInvalidArgument
	}
	user, err := store.GetUserByID(ctx, uint(userID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	user.FeishuEmail = email
	if err := store.SaveUser(ctx, &user); err != nil {
		return nil, err
	}
	return &userv1.BindFeishuResp{User: ModelToUserV1(&user)}, nil
}

// UnbindFeishu 解绑飞书邮箱。
func UnbindFeishu(ctx context.Context, store UserStore, in *userv1.UnbindFeishuReq) (*userv1.UnbindFeishuResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil || userID == 0 {
		return nil, ErrInvalidArgument
	}
	user, err := store.GetUserByID(ctx, uint(userID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	user.FeishuEmail = ""
	if err := store.SaveUser(ctx, &user); err != nil {
		return nil, err
	}
	return &userv1.UnbindFeishuResp{User: ModelToUserV1(&user)}, nil
}

// SendFeishuTestCard 发送飞书测试卡片。
func SendFeishuTestCard(ctx context.Context, store UserStore, in *userv1.SendFeishuTestCardReq) (*userv1.SendFeishuTestCardResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil || userID == 0 {
		return nil, ErrInvalidArgument
	}
	user, err := store.GetUserSelectedFields(ctx, uint(userID), "id", "feishu_email")
	if err != nil {
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
	return &userv1.SendFeishuTestCardResp{}, nil
}

func findOrCreateFeishuUser(ctx context.Context, store UserStore, info utils.FeishuOAuthUserInfo) (model.User, bool, error) {
	openID := strings.TrimSpace(info.OpenID)
	user, err := store.FindUserByFeishuOpenID(ctx, openID)
	if err == nil {
		applyFeishuProfile(&user, info)
		if err := store.SaveUser(ctx, &user); err != nil {
			return model.User{}, false, err
		}
		return user, false, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return model.User{}, false, err
	}

	email := strings.TrimSpace(info.Email)
	if email != "" {
		user, err = store.FindUserByEmail(ctx, email)
		if err == nil {
			applyFeishuProfile(&user, info)
			if err := store.SaveUser(ctx, &user); err != nil {
				return model.User{}, false, err
			}
			return user, false, nil
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return model.User{}, false, err
		}
	}

	username, err := allocateFeishuUsername(ctx, store, info.Name, email)
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
	if err := store.CreateUser(ctx, &user); err != nil {
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

func allocateFeishuUsername(ctx context.Context, store UserStore, feishuName, email string) (string, error) {
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
		taken, err := store.UsernameTaken(ctx, candidate)
		if err != nil {
			return "", err
		}
		if !taken {
			return candidate, nil
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
