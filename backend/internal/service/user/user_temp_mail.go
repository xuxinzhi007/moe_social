package userapp

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"

	userv1 "backend/api/user/v1"
	"backend/utils"

	kerrors "github.com/go-kratos/kratos/v2/errors"
	"github.com/spf13/viper"
)

type mailTmDomainListResponse struct {
	HydraMember []mailTmDomainItem `json:"hydra:member"`
}

type mailTmDomainItem struct {
	Domain string `json:"domain"`
}

type mailTmTokenResponse struct {
	Token string `json:"token"`
}

type mailTmCreateAccountRequest struct {
	Address  string `json:"address"`
	Password string `json:"password"`
}

type mailTmMessageListResponse struct {
	HydraMember []mailTmMessageItem `json:"hydra:member"`
}

type mailTmMessageItem struct {
	ID             string `json:"id"`
	Subject        string `json:"subject"`
	Text           string `json:"text"`
	HTML           any    `json:"html"`
	Intro          string `json:"intro"`
	CreatedAt      string `json:"createdAt"`
	Seen           bool   `json:"seen"`
	From           any    `json:"from"`
	To             any    `json:"to"`
	HasAttachments bool   `json:"hasAttachments"`
}

var (
	tempMailCodeRegex = regexp.MustCompile(`\b\d{6}\b|\b\d{4,8}\b`)
	tempMailHTMLTagRE = regexp.MustCompile(`<[^>]+>`)
	tempMailDomainMu  sync.RWMutex
	tempMailDomain    string
)

func (s *AppService) GenerateTempEmail(ctx context.Context, _ *userv1.GenerateTempEmailReq) (*userv1.GenerateTempEmailResp, error) {
	client, baseURL, err := loadTempMailConfig()
	if err != nil {
		return nil, err
	}

	domain, err := mailTmPickDomainForGenerate(ctx, client, baseURL)
	if err != nil {
		return nil, err
	}

	localPart := buildTempMailboxLocalPart()
	email := localPart + "@" + domain
	password := tempMailboxPassword(email)

	if err := mailTmEnsureAccount(ctx, client, baseURL, email, password); err != nil {
		if isRetryableTempMailError(err) {
			go prepareTempMailboxInBackground(baseURL, email, password)
		} else {
			return nil, err
		}
	}

	return &userv1.GenerateTempEmailResp{
		Email:     email,
		LocalPart: localPart,
		Domain:    domain,
	}, nil
}

func (s *AppService) GetTempEmailLatestCode(ctx context.Context, in *userv1.GetTempEmailLatestCodeReq) (*userv1.GetTempEmailLatestCodeResp, error) {
	email := strings.ToLower(strings.TrimSpace(in.GetEmail()))
	if email == "" || !strings.Contains(email, "@") {
		return nil, kerrors.BadRequest("TEMP_MAIL_EMAIL_REQUIRED", "邮箱地址不能为空")
	}

	client, baseURL, err := loadTempMailConfig()
	if err != nil {
		return nil, err
	}

	password := tempMailboxPassword(email)
	if err := mailTmEnsureAccount(ctx, client, baseURL, email, password); err != nil {
		return nil, err
	}

	token, err := mailTmToken(ctx, client, baseURL, email, password)
	if err != nil {
		return nil, err
	}

	message, err := mailTmLatestMessage(ctx, client, baseURL, token)
	if err != nil {
		return nil, err
	}
	if message == nil {
		return &userv1.GetTempEmailLatestCodeResp{}, nil
	}

	code := extractTempMailCode(
		message.Subject,
		message.Text,
		message.Intro,
		flattenMailTmHTML(message.HTML),
	)

	return &userv1.GetTempEmailLatestCodeResp{
		Code:       code,
		Matched:    code != "",
		MessageId:  message.ID,
		Subject:    message.Subject,
		ReceivedAt: message.CreatedAt,
	}, nil
}

func loadTempMailConfig() (*http.Client, string, error) {
	if !viper.GetBool("temp_mail.enabled") {
		return nil, "", kerrors.BadRequest("TEMP_MAIL_DISABLED", "临时邮箱功能暂未启用")
	}

	baseURL := strings.TrimRight(strings.TrimSpace(viper.GetString("temp_mail.base_url")), "/")
	if baseURL == "" {
		baseURL = "https://api.mail.tm"
	}

	timeoutSeconds := viper.GetInt("temp_mail.timeout_seconds")
	return utils.NewHTTPClient(timeoutSeconds), baseURL, nil
}

func mailTmPickDomain(ctx context.Context, client *http.Client, baseURL string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, baseURL+"/domains?page=1", nil)
	if err != nil {
		return "", kerrors.InternalServer("TEMP_MAIL_REQUEST_BUILD_FAILED", err.Error())
	}

	var payload mailTmDomainListResponse
	if err := doJSON(client, req, &payload); err != nil {
		return "", err
	}
	for _, item := range payload.HydraMember {
		domain := strings.TrimSpace(item.Domain)
		if domain != "" {
			cacheTempMailDomain(domain)
			return domain, nil
		}
	}
	return "", kerrors.InternalServer("TEMP_MAIL_DOMAIN_EMPTY", "临时邮箱域名列表为空")
}

func mailTmPickDomainForGenerate(ctx context.Context, client *http.Client, baseURL string) (string, error) {
	domain, err := mailTmPickDomain(ctx, client, baseURL)
	if err == nil {
		return domain, nil
	}

	if cached := getCachedTempMailDomain(); cached != "" {
		return cached, nil
	}

	if fallback := strings.ToLower(strings.TrimSpace(viper.GetString("temp_mail.fallback_domain"))); fallback != "" {
		cacheTempMailDomain(fallback)
		return fallback, nil
	}

	return "", err
}

func mailTmEnsureAccount(ctx context.Context, client *http.Client, baseURL string, email string, password string) error {
	body, _ := json.Marshal(mailTmCreateAccountRequest{
		Address:  email,
		Password: password,
	})

	var lastErr error
	for attempt := 0; attempt < 2; attempt++ {
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/accounts", bytes.NewReader(body))
		if err != nil {
			return kerrors.InternalServer("TEMP_MAIL_REQUEST_BUILD_FAILED", err.Error())
		}
		req.Header.Set("Content-Type", "application/json")

		resp, respBody, err := doRaw(client, req)
		if err != nil {
			lastErr = err
			if attempt == 0 && isTempMailTimeoutError(err) {
				time.Sleep(250 * time.Millisecond)
				continue
			}
			return err
		}

		if resp.StatusCode >= 200 && resp.StatusCode < 300 {
			resp.Body.Close()
			return nil
		}

		trimmed := strings.TrimSpace(string(respBody))
		if resp.StatusCode == http.StatusConflict || strings.Contains(trimmed, "already used") {
			resp.Body.Close()
			return nil
		}

		lastErr = kerrors.InternalServer("TEMP_MAIL_CREATE_FAILED", mailTmHTTPError(resp.StatusCode, respBody))
		resp.Body.Close()
		if attempt == 0 && resp.StatusCode >= http.StatusInternalServerError {
			time.Sleep(250 * time.Millisecond)
			continue
		}
		return lastErr
	}

	if lastErr != nil {
		return lastErr
	}
	return kerrors.InternalServer("TEMP_MAIL_CREATE_FAILED", "临时邮箱创建失败，请稍后重试")
}

func mailTmToken(ctx context.Context, client *http.Client, baseURL string, email string, password string) (string, error) {
	body, _ := json.Marshal(mailTmCreateAccountRequest{
		Address:  email,
		Password: password,
	})

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/token", bytes.NewReader(body))
	if err != nil {
		return "", kerrors.InternalServer("TEMP_MAIL_REQUEST_BUILD_FAILED", err.Error())
	}
	req.Header.Set("Content-Type", "application/json")

	var payload mailTmTokenResponse
	if err := doJSON(client, req, &payload); err != nil {
		return "", err
	}
	token := strings.TrimSpace(payload.Token)
	if token == "" {
		return "", kerrors.InternalServer("TEMP_MAIL_TOKEN_EMPTY", "临时邮箱令牌获取失败")
	}
	return token, nil
}

func mailTmLatestMessage(ctx context.Context, client *http.Client, baseURL string, token string) (*mailTmMessageItem, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, baseURL+"/messages?page=1", nil)
	if err != nil {
		return nil, kerrors.InternalServer("TEMP_MAIL_REQUEST_BUILD_FAILED", err.Error())
	}
	req.Header.Set("Authorization", "Bearer "+token)

	var payload mailTmMessageListResponse
	if err := doJSON(client, req, &payload); err != nil {
		return nil, err
	}
	if len(payload.HydraMember) == 0 {
		return nil, nil
	}
	return &payload.HydraMember[0], nil
}

func doJSON(client *http.Client, req *http.Request, out any) error {
	resp, body, err := doRaw(client, req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return kerrors.InternalServer("TEMP_MAIL_REQUEST_FAILED", mailTmHTTPError(resp.StatusCode, body))
	}
	if err := json.Unmarshal(body, out); err != nil {
		return kerrors.InternalServer("TEMP_MAIL_RESPONSE_INVALID", "临时邮箱服务返回格式异常")
	}
	return nil
}

func doRaw(client *http.Client, req *http.Request) (*http.Response, []byte, error) {
	resp, err := client.Do(req)
	if err != nil {
		var netErr net.Error
		if errors.Is(err, context.DeadlineExceeded) || (errors.As(err, &netErr) && netErr.Timeout()) {
			return nil, nil, kerrors.InternalServer("TEMP_MAIL_REQUEST_TIMEOUT", "临时邮箱服务响应超时，请稍后重试")
		}
		return nil, nil, kerrors.InternalServer("TEMP_MAIL_REQUEST_FAILED", err.Error())
	}

	body, readErr := io.ReadAll(resp.Body)
	if readErr != nil {
		resp.Body.Close()
		return nil, nil, kerrors.InternalServer("TEMP_MAIL_REQUEST_FAILED", readErr.Error())
	}

	resp.Body = io.NopCloser(bytes.NewReader(body))
	return resp, body, nil
}

func isTempMailTimeoutError(err error) bool {
	se := kerrors.FromError(err)
	return strings.TrimSpace(se.Reason) == "TEMP_MAIL_REQUEST_TIMEOUT"
}

func cacheTempMailDomain(domain string) {
	normalized := strings.ToLower(strings.TrimSpace(domain))
	if normalized == "" {
		return
	}
	tempMailDomainMu.Lock()
	tempMailDomain = normalized
	tempMailDomainMu.Unlock()
}

func getCachedTempMailDomain() string {
	tempMailDomainMu.RLock()
	defer tempMailDomainMu.RUnlock()
	return tempMailDomain
}

func isRetryableTempMailError(err error) bool {
	se := kerrors.FromError(err)
	switch strings.TrimSpace(se.Reason) {
	case "TEMP_MAIL_REQUEST_TIMEOUT", "TEMP_MAIL_REQUEST_FAILED", "TEMP_MAIL_CREATE_FAILED":
		return true
	default:
		return false
	}
}

func prepareTempMailboxInBackground(baseURL string, email string, password string) {
	client := utils.NewHTTPClient(30)
	for attempt := 0; attempt < 3; attempt++ {
		ctx, cancel := context.WithTimeout(context.Background(), 12*time.Second)
		err := mailTmEnsureAccount(ctx, client, baseURL, email, password)
		cancel()
		if err == nil || !isRetryableTempMailError(err) {
			return
		}
		time.Sleep(time.Duration(attempt+1) * time.Second)
	}
}

func mailTmHTTPError(statusCode int, body []byte) string {
	text := strings.TrimSpace(string(body))
	if text == "" {
		return fmt.Sprintf("临时邮箱请求失败（状态码 %d）", statusCode)
	}
	if len(text) > 200 {
		text = text[:200]
	}
	return fmt.Sprintf("临时邮箱请求失败（状态码 %d）：%s", statusCode, text)
}

func buildTempMailboxLocalPart() string {
	const alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
	buf := make([]byte, 12)
	if _, err := rand.Read(buf); err != nil {
		sum := sha256.Sum256([]byte(fmt.Sprintf("fallback-%d", len(buf))))
		copy(buf, sum[:len(buf)])
	}
	for i := range buf {
		buf[i] = alphabet[int(buf[i])%len(alphabet)]
	}
	return "moe" + string(buf)
}

func tempMailboxPassword(email string) string {
	seed := strings.TrimSpace(viper.GetString("auth.access_secret"))
	if seed == "" {
		seed = "moe-social-temp-mail"
	}
	sum := sha256.Sum256([]byte(strings.ToLower(email) + "|" + seed))
	return hex.EncodeToString(sum[:16])
}

func flattenMailTmHTML(v any) string {
	switch t := v.(type) {
	case string:
		return tempMailHTMLTagRE.ReplaceAllString(t, " ")
	case []any:
		parts := make([]string, 0, len(t))
		for _, item := range t {
			parts = append(parts, flattenMailTmHTML(item))
		}
		return strings.Join(parts, " ")
	default:
		return ""
	}
}

func extractTempMailCode(sources ...string) string {
	for _, source := range sources {
		if source == "" {
			continue
		}
		if match := tempMailCodeRegex.FindString(source); match != "" {
			return match
		}
	}
	return ""
}
