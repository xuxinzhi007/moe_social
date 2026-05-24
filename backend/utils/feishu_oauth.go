package utils

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"

	"github.com/spf13/viper"
)

// FeishuOAuthUserInfo 飞书 OAuth 用户资料。
type FeishuOAuthUserInfo struct {
	OpenID  string
	UnionID string
	Name    string
	Email   string
	Avatar  string
}

// FeishuOAuthRedirectURI 回调地址；未配置 feishu.redirect_uri 时用 api.public_base_url 拼接。
func FeishuOAuthRedirectURI() string {
	if u := strings.TrimSpace(viper.GetString("feishu.redirect_uri")); u != "" {
		return u
	}
	base := strings.TrimRight(strings.TrimSpace(viper.GetString("api.public_base_url")), "/")
	if base == "" {
		return ""
	}
	return base + "/api/auth/feishu/callback"
}

// FeishuOAuthAuthorizeURL 生成飞书网页授权地址。
func FeishuOAuthAuthorizeURL(state string) (string, error) {
	appID := strings.TrimSpace(viper.GetString("feishu.app_id"))
	redirectURI := FeishuOAuthRedirectURI()
	if appID == "" {
		return "", fmt.Errorf("feishu app_id is empty")
	}
	if redirectURI == "" {
		return "", fmt.Errorf("feishu redirect_uri is empty (set feishu.redirect_uri or api.public_base_url)")
	}
	if state == "" {
		state = "moe_social"
	}
	q := url.Values{}
	q.Set("app_id", appID)
	q.Set("redirect_uri", redirectURI)
	q.Set("state", state)
	scope := strings.TrimSpace(viper.GetString("feishu.oauth_scope"))
	if scope == "" {
		scope = "contact:user.email:readonly"
	}
	q.Set("scope", scope)
	return "https://open.feishu.cn/open-apis/authen/v1/authorize?" + q.Encode(), nil
}

// ExchangeFeishuOAuthCode 用授权码换取用户 access_token 并拉取资料。
func ExchangeFeishuOAuthCode(ctx context.Context, code string) (FeishuOAuthUserInfo, error) {
	code = strings.TrimSpace(code)
	if code == "" {
		return FeishuOAuthUserInfo{}, fmt.Errorf("feishu oauth code is empty")
	}
	appID := strings.TrimSpace(viper.GetString("feishu.app_id"))
	appSecret := strings.TrimSpace(viper.GetString("feishu.app_secret"))
	redirectURI := FeishuOAuthRedirectURI()
	if appID == "" || appSecret == "" {
		return FeishuOAuthUserInfo{}, fmt.Errorf("feishu app credentials missing")
	}

	appToken, err := getFeishuTenantAccessToken(ctx, appID, appSecret)
	if err != nil {
		return FeishuOAuthUserInfo{}, err
	}

	userAccessToken, err := feishuOIDCAccessToken(ctx, appToken, code, redirectURI)
	if err != nil {
		return FeishuOAuthUserInfo{}, err
	}
	return feishuFetchUserInfo(ctx, userAccessToken)
}

func feishuOIDCAccessToken(ctx context.Context, appToken, code, redirectURI string) (string, error) {
	payload, err := json.Marshal(map[string]string{
		"grant_type":   "authorization_code",
		"code":         code,
		"redirect_uri": redirectURI,
	})
	if err != nil {
		return "", fmt.Errorf("marshal feishu oidc request: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, feishuAPIBase+"/authen/v1/oidc/access_token", bytes.NewReader(payload))
	if err != nil {
		return "", fmt.Errorf("build feishu oidc request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+appToken)

	resp, err := NewHTTPClient(8).Do(req)
	if err != nil {
		return "", fmt.Errorf("post feishu oidc token: %w", err)
	}
	defer resp.Body.Close()
	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("feishu oidc http %d: %s", resp.StatusCode, strings.TrimSpace(string(bodyBytes)))
	}

	var parsed struct {
		Code int    `json:"code"`
		Msg  string `json:"msg"`
		Data struct {
			AccessToken string `json:"access_token"`
		} `json:"data"`
	}
	if err := json.Unmarshal(bodyBytes, &parsed); err != nil {
		return "", fmt.Errorf("decode feishu oidc response: %w", err)
	}
	if parsed.Code != 0 {
		return "", fmt.Errorf("feishu oidc error code=%d msg=%s", parsed.Code, parsed.Msg)
	}
	if strings.TrimSpace(parsed.Data.AccessToken) == "" {
		return "", fmt.Errorf("feishu oidc missing access_token")
	}
	return parsed.Data.AccessToken, nil
}

func feishuFetchUserInfo(ctx context.Context, userAccessToken string) (FeishuOAuthUserInfo, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, feishuAPIBase+"/authen/v1/user_info", nil)
	if err != nil {
		return FeishuOAuthUserInfo{}, fmt.Errorf("build feishu user_info request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+userAccessToken)

	resp, err := NewHTTPClient(8).Do(req)
	if err != nil {
		return FeishuOAuthUserInfo{}, fmt.Errorf("get feishu user_info: %w", err)
	}
	defer resp.Body.Close()
	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return FeishuOAuthUserInfo{}, fmt.Errorf("feishu user_info http %d: %s", resp.StatusCode, strings.TrimSpace(string(bodyBytes)))
	}

	var parsed struct {
		Code int    `json:"code"`
		Msg  string `json:"msg"`
		Data struct {
			OpenID    string `json:"open_id"`
			UnionID   string `json:"union_id"`
			Name      string `json:"name"`
			EnName    string `json:"en_name"`
			Email     string `json:"email"`
			AvatarURL string `json:"avatar_url"`
		} `json:"data"`
	}
	if err := json.Unmarshal(bodyBytes, &parsed); err != nil {
		return FeishuOAuthUserInfo{}, fmt.Errorf("decode feishu user_info: %w", err)
	}
	if parsed.Code != 0 {
		return FeishuOAuthUserInfo{}, fmt.Errorf("feishu user_info error code=%d msg=%s", parsed.Code, parsed.Msg)
	}

	name := strings.TrimSpace(parsed.Data.Name)
	if name == "" {
		name = strings.TrimSpace(parsed.Data.EnName)
	}
	openID := strings.TrimSpace(parsed.Data.OpenID)
	if openID == "" {
		openID = strings.TrimSpace(parsed.Data.UnionID)
	}
	if openID == "" {
		return FeishuOAuthUserInfo{}, fmt.Errorf("feishu user_info missing open_id")
	}

	email := strings.TrimSpace(parsed.Data.Email)
	if email != "" {
		normalized, err := NormalizeFeishuEmail(email)
		if err == nil {
			email = normalized
		}
	}

	return FeishuOAuthUserInfo{
		OpenID:  openID,
		UnionID: strings.TrimSpace(parsed.Data.UnionID),
		Name:    name,
		Email:   email,
		Avatar:  strings.TrimSpace(parsed.Data.AvatarURL),
	}, nil
}
