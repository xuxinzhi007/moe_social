package utils

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/spf13/viper"
)

const feishuAPIBase = "https://open.feishu.cn/open-apis"

// FeishuAgentCreatedNotification 兼容旧字段名（CreatedAt → EventAt）。
type FeishuAgentCreatedNotification struct {
	UserName        string
	UserID          string
	AgentID         string
	AgentName       string
	Description     string
	ModelName       string
	ProviderProfile string
	CreatedAt       time.Time
}

type feishuTokenCache struct {
	mu        sync.Mutex
	token     string
	expiresAt time.Time
}

var feishuTokens feishuTokenCache

// SendFeishuAgentCreatedNotification posts an interactive card via a self-built Feishu app bot.
// recipientEmail 优先（用户绑定的企业飞书邮箱）；为空时回退 config 中的 receive_id。
func SendFeishuAgentCreatedNotification(ctx context.Context, n FeishuAgentCreatedNotification, recipientEmail string) error {
	eventAt := n.CreatedAt
	if eventAt.IsZero() {
		eventAt = time.Now()
	}
	return SendFeishuAgentEventNotification(ctx, FeishuAgentEvent{
		Action:          FeishuAgentCreated,
		UserName:        n.UserName,
		UserID:          n.UserID,
		AgentID:         n.AgentID,
		AgentName:       n.AgentName,
		Description:     n.Description,
		ModelName:       n.ModelName,
		ProviderProfile: n.ProviderProfile,
		EventAt:         eventAt,
	}, recipientEmail)
}

// SendFeishuTestCard sends a sample agent-created card for manual verification.
func SendFeishuTestCard(ctx context.Context, recipientEmail string) error {
	n := FeishuAgentCreatedNotification{
		UserName:        "测试用户",
		UserID:          "0",
		AgentID:         "test_agent",
		AgentName:       "测试角色卡",
		Description:     "这是一条飞书消息卡片测试，用于验证自建应用机器人配置。",
		ModelName:       "test-model",
		ProviderProfile: "builtin",
		CreatedAt:       time.Now(),
	}
	return SendFeishuAgentEventNotification(ctx, FeishuAgentEvent{
		Action:          FeishuAgentCreated,
		UserName:        n.UserName,
		UserID:          n.UserID,
		AgentID:         n.AgentID,
		AgentName:       n.AgentName,
		Description:     n.Description,
		ModelName:       n.ModelName,
		ProviderProfile: n.ProviderProfile,
		EventAt:         n.CreatedAt,
	}, recipientEmail)
}

func resolveFeishuRecipient(recipientEmail string) (receiveID, receiveIDType string, err error) {
	if !viper.GetBool("feishu.enabled") {
		return "", "", fmt.Errorf("feishu is disabled")
	}
	receiveID = strings.TrimSpace(recipientEmail)
	receiveIDType = "email"
	if receiveID == "" {
		receiveID = strings.TrimSpace(viper.GetString("feishu.receive_id"))
		receiveIDType = strings.TrimSpace(viper.GetString("feishu.receive_id_type"))
		if receiveIDType == "" {
			receiveIDType = "email"
		}
	}
	if receiveID == "" {
		return "", "", fmt.Errorf("feishu receive target is empty: bind user feishu email or set feishu.receive_id")
	}
	return receiveID, receiveIDType, nil
}

func sendFeishuInteractiveCard(ctx context.Context, receiveIDType, receiveID string, card map[string]interface{}) error {
	if !viper.GetBool("feishu.enabled") {
		return nil
	}
	appID := strings.TrimSpace(viper.GetString("feishu.app_id"))
	appSecret := strings.TrimSpace(viper.GetString("feishu.app_secret"))
	if appID == "" {
		return fmt.Errorf("feishu app_id is empty")
	}
	if appSecret == "" {
		return fmt.Errorf("feishu app_secret is empty")
	}

	token, err := getFeishuTenantAccessToken(ctx, appID, appSecret)
	if err != nil {
		return err
	}

	cardJSON, err := json.Marshal(card)
	if err != nil {
		return fmt.Errorf("marshal feishu card: %w", err)
	}
	return sendFeishuIMMessage(ctx, token, receiveIDType, receiveID, "interactive", string(cardJSON))
}

// NormalizeFeishuEmail validates and normalizes an enterprise Feishu email.
func NormalizeFeishuEmail(raw string) (string, error) {
	email := strings.TrimSpace(strings.ToLower(raw))
	if email == "" {
		return "", fmt.Errorf("feishu email is empty")
	}
	if len(email) > 100 {
		return "", fmt.Errorf("feishu email too long")
	}
	if !strings.Contains(email, "@") || strings.HasPrefix(email, "@") || strings.HasSuffix(email, "@") {
		return "", fmt.Errorf("invalid feishu email format")
	}
	return email, nil
}

func getFeishuTenantAccessToken(ctx context.Context, appID, appSecret string) (string, error) {
	feishuTokens.mu.Lock()
	if feishuTokens.token != "" && time.Now().Before(feishuTokens.expiresAt) {
		token := feishuTokens.token
		feishuTokens.mu.Unlock()
		return token, nil
	}
	feishuTokens.mu.Unlock()

	body, err := json.Marshal(map[string]string{
		"app_id":     appID,
		"app_secret": appSecret,
	})
	if err != nil {
		return "", fmt.Errorf("marshal feishu token request: %w", err)
	}

	req, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		feishuAPIBase+"/auth/v3/tenant_access_token/internal",
		bytes.NewReader(body),
	)
	if err != nil {
		return "", fmt.Errorf("build feishu token request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := NewHTTPClient(8).Do(req)
	if err != nil {
		return "", fmt.Errorf("post feishu token: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("feishu token http %d: %s", resp.StatusCode, strings.TrimSpace(string(respBody)))
	}

	var parsed struct {
		Code              int    `json:"code"`
		Msg               string `json:"msg"`
		TenantAccessToken string `json:"tenant_access_token"`
		Expire            int    `json:"expire"`
	}
	if err := json.Unmarshal(respBody, &parsed); err != nil {
		return "", fmt.Errorf("decode feishu token response: %w", err)
	}
	if parsed.Code != 0 {
		return "", fmt.Errorf("feishu token error code=%d msg=%s", parsed.Code, parsed.Msg)
	}
	if strings.TrimSpace(parsed.TenantAccessToken) == "" {
		return "", fmt.Errorf("feishu token response missing tenant_access_token")
	}

	expireSeconds := parsed.Expire
	if expireSeconds <= 0 {
		expireSeconds = 7200
	}
	// Refresh a bit early to avoid edge expiry during downstream calls.
	cacheUntil := time.Now().Add(time.Duration(expireSeconds-120) * time.Second)
	if cacheUntil.Before(time.Now()) {
		cacheUntil = time.Now().Add(30 * time.Minute)
	}

	feishuTokens.mu.Lock()
	feishuTokens.token = parsed.TenantAccessToken
	feishuTokens.expiresAt = cacheUntil
	feishuTokens.mu.Unlock()

	return parsed.TenantAccessToken, nil
}

func sendFeishuIMMessage(ctx context.Context, token, receiveIDType, receiveID, msgType, content string) error {
	endpoint, err := url.Parse(feishuAPIBase + "/im/v1/messages")
	if err != nil {
		return fmt.Errorf("parse feishu im endpoint: %w", err)
	}
	q := endpoint.Query()
	q.Set("receive_id_type", receiveIDType)
	endpoint.RawQuery = q.Encode()

	payload, err := json.Marshal(map[string]string{
		"receive_id": receiveID,
		"msg_type":   msgType,
		"content":    content,
	})
	if err != nil {
		return fmt.Errorf("marshal feishu im message: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint.String(), bytes.NewReader(payload))
	if err != nil {
		return fmt.Errorf("build feishu im request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := NewHTTPClient(8).Do(req)
	if err != nil {
		return fmt.Errorf("post feishu im message: %w", err)
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("feishu im http %d: %s", resp.StatusCode, strings.TrimSpace(string(bodyBytes)))
	}

	var bodyMap map[string]interface{}
	if len(bodyBytes) > 0 {
		_ = json.Unmarshal(bodyBytes, &bodyMap)
	}
	if code, ok := numericField(bodyMap, "code"); ok && code != 0 {
		return fmt.Errorf("feishu im error code=%d msg=%s", code, stringField(bodyMap, "msg"))
	}

	return nil
}

func sanitizeCardText(value string, maxRunes int) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}
	value = strings.ReplaceAll(value, "\r\n", "\n")
	value = strings.ReplaceAll(value, "\r", "\n")
	value = strings.ReplaceAll(value, "\n", " ")
	value = strings.Join(strings.Fields(value), " ")
	value = escapeMarkdown(value)
	if maxRunes > 0 {
		value = truncateRunes(value, maxRunes)
	}
	return value
}

func escapeMarkdown(value string) string {
	replacer := strings.NewReplacer(
		`\\`, `\\\\`,
		`*`, `\*`,
		`_`, `\_`,
		`~`, `\~`,
		"`", "\\`",
		`[`, `\[`,
		`]`, `\]`,
	)
	return replacer.Replace(value)
}

func truncateRunes(value string, maxRunes int) string {
	runes := []rune(value)
	if len(runes) <= maxRunes {
		return value
	}
	if maxRunes <= 3 {
		return string(runes[:maxRunes])
	}
	return string(runes[:maxRunes-3]) + "..."
}

func numericField(m map[string]interface{}, key string) (int, bool) {
	if m == nil {
		return 0, false
	}
	raw, ok := m[key]
	if !ok || raw == nil {
		return 0, false
	}
	switch v := raw.(type) {
	case float64:
		return int(v), true
	case float32:
		return int(v), true
	case int:
		return v, true
	case int32:
		return int(v), true
	case int64:
		return int(v), true
	case json.Number:
		n, err := v.Int64()
		if err != nil {
			return 0, false
		}
		return int(n), true
	case string:
		n, err := strconv.Atoi(strings.TrimSpace(v))
		if err != nil {
			return 0, false
		}
		return n, true
	default:
		return 0, false
	}
}

func stringField(m map[string]interface{}, key string) string {
	if m == nil {
		return ""
	}
	raw, ok := m[key]
	if !ok || raw == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(raw))
}
