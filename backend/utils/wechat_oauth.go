package utils

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/spf13/viper"
)

func wechatRedirectURI() (string, error) {
	redirectURI := strings.TrimSpace(viper.GetString("wechat.redirect_uri"))
	if redirectURI == "" {
		return "", fmt.Errorf("wechat redirect_uri is empty")
	}
	return redirectURI, nil
}

// WechatWebsiteAuthorizeURL 开放平台「网站应用」扫码登录（PC/Web 浏览器可用）。
func WechatWebsiteAuthorizeURL(state string) (string, error) {
	if !viper.GetBool("wechat.enabled") {
		return "", fmt.Errorf("wechat oauth is disabled")
	}
	appID, _, err := wechatFlowCredentials("website")
	if err != nil {
		return "", err
	}
	redirectURI, err := wechatRedirectURI()
	if err != nil {
		return "", err
	}
	if state == "" {
		state = "moe_social"
	}
	q := url.Values{}
	q.Set("appid", appID)
	q.Set("redirect_uri", redirectURI)
	q.Set("response_type", "code")
	q.Set("scope", "snsapi_login")
	q.Set("state", state)
	return "https://open.weixin.qq.com/connect/qrconnect?" + q.Encode() + "#wechat_redirect", nil
}

// WechatOAuthAuthorizeURL 公众号网页授权（仅适合在微信内置浏览器打开）。
func WechatOAuthAuthorizeURL(state string) (string, error) {
	if !viper.GetBool("wechat.enabled") {
		return "", fmt.Errorf("wechat oauth is disabled")
	}
	appID, _, err := wechatFlowCredentials("mp")
	if err != nil {
		return "", err
	}
	redirectURI, err := wechatRedirectURI()
	if err != nil {
		return "", err
	}
	if state == "" {
		state = "moe_social"
	}
	scope := strings.TrimSpace(viper.GetString("wechat.oauth_scope"))
	if scope == "" {
		scope = "snsapi_userinfo"
	}
	q := url.Values{}
	q.Set("appid", appID)
	q.Set("redirect_uri", redirectURI)
	q.Set("response_type", "code")
	q.Set("scope", scope)
	q.Set("state", state)
	return "https://open.weixin.qq.com/connect/oauth2/authorize?" + q.Encode() + "#wechat_redirect", nil
}

// WechatOAuthAuthorizeURLForFlow website | mp
func WechatOAuthAuthorizeURLForFlow(state, flow string) (string, error) {
	switch NormalizeWechatOAuthFlow(flow) {
	case "website":
		return WechatWebsiteAuthorizeURL(state)
	case "mp":
		return WechatOAuthAuthorizeURL(state)
	default:
		return "", fmt.Errorf("authorize-url unsupported for flow %q (use app SDK on mobile)", flow)
	}
}

// WechatOAuthUserInfo 微信 OAuth 用户资料。
type WechatOAuthUserInfo struct {
	OpenID   string
	UnionID  string
	Nickname string
	Avatar   string
}

type wechatTokenResp struct {
	AccessToken  string `json:"access_token"`
	ExpiresIn    int    `json:"expires_in"`
	RefreshToken string `json:"refresh_token"`
	OpenID       string `json:"openid"`
	Scope        string `json:"scope"`
	UnionID      string `json:"unionid"`
	ErrCode      int    `json:"errcode"`
	ErrMsg       string `json:"errmsg"`
}

type wechatUserInfoResp struct {
	OpenID     string `json:"openid"`
	Nickname   string `json:"nickname"`
	HeadImgURL string `json:"headimgurl"`
	UnionID    string `json:"unionid"`
	ErrCode    int    `json:"errcode"`
	ErrMsg     string `json:"errmsg"`
}

// ExchangeWechatOAuthCode 用授权码换取 openid（flow: app | website | mp）。
func ExchangeWechatOAuthCode(ctx context.Context, code, flow string) (WechatOAuthUserInfo, error) {
	code = strings.TrimSpace(code)
	if code == "" {
		return WechatOAuthUserInfo{}, fmt.Errorf("wechat oauth code is empty")
	}
	if !viper.GetBool("wechat.enabled") {
		return WechatOAuthUserInfo{}, fmt.Errorf("wechat oauth is disabled")
	}
	flow = NormalizeWechatOAuthFlow(flow)
	if flow == "" {
		flow = "website"
	}
	appID, appSecret, err := wechatFlowCredentials(flow)
	if err != nil {
		return WechatOAuthUserInfo{}, err
	}

	token, err := wechatOAuthAccessToken(ctx, appID, appSecret, code)
	if err != nil {
		return WechatOAuthUserInfo{}, err
	}
	info := WechatOAuthUserInfo{
		OpenID:  strings.TrimSpace(token.OpenID),
		UnionID: strings.TrimSpace(token.UnionID),
	}
	if info.OpenID == "" {
		return WechatOAuthUserInfo{}, fmt.Errorf("wechat oauth openid is empty")
	}
	scope := strings.TrimSpace(token.Scope)
	if scope == "" {
		scope = "snsapi_login"
	}
	if strings.Contains(scope, "snsapi_userinfo") && strings.TrimSpace(token.AccessToken) != "" {
		profile, err := wechatFetchUserInfo(ctx, token.AccessToken, info.OpenID)
		if err != nil {
			return info, nil
		}
		info.Nickname = strings.TrimSpace(profile.Nickname)
		info.Avatar = strings.TrimSpace(profile.HeadImgURL)
		if u := strings.TrimSpace(profile.UnionID); u != "" {
			info.UnionID = u
		}
	}
	return info, nil
}

func wechatOAuthAccessToken(ctx context.Context, appID, appSecret, code string) (wechatTokenResp, error) {
	q := url.Values{}
	q.Set("appid", appID)
	q.Set("secret", appSecret)
	q.Set("code", code)
	q.Set("grant_type", "authorization_code")
	endpoint := "https://api.weixin.qq.com/sns/oauth2/access_token?" + q.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return wechatTokenResp{}, err
	}
	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return wechatTokenResp{}, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return wechatTokenResp{}, err
	}
	var out wechatTokenResp
	if err := json.Unmarshal(body, &out); err != nil {
		return wechatTokenResp{}, err
	}
	if out.ErrCode != 0 {
		return wechatTokenResp{}, fmt.Errorf("wechat token api: %d %s", out.ErrCode, out.ErrMsg)
	}
	if strings.TrimSpace(out.OpenID) == "" {
		return wechatTokenResp{}, fmt.Errorf("wechat token api: empty openid")
	}
	return out, nil
}

func wechatFetchUserInfo(ctx context.Context, accessToken, openID string) (wechatUserInfoResp, error) {
	q := url.Values{}
	q.Set("access_token", accessToken)
	q.Set("openid", openID)
	q.Set("lang", "zh_CN")
	endpoint := "https://api.weixin.qq.com/sns/userinfo?" + q.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return wechatUserInfoResp{}, err
	}
	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return wechatUserInfoResp{}, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return wechatUserInfoResp{}, err
	}
	var out wechatUserInfoResp
	if err := json.Unmarshal(body, &out); err != nil {
		return wechatUserInfoResp{}, err
	}
	if out.ErrCode != 0 {
		return wechatUserInfoResp{}, fmt.Errorf("wechat userinfo api: %d %s", out.ErrCode, out.ErrMsg)
	}
	return out, nil
}
