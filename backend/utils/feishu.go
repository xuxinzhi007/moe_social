package utils

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/viper"
)

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

func SendFeishuAgentCreatedNotification(ctx context.Context, n FeishuAgentCreatedNotification) error {
	if !viper.GetBool("feishu.enabled") {
		return nil
	}

	webhook := strings.TrimSpace(viper.GetString("feishu.webhook_url"))
	if webhook == "" {
		return fmt.Errorf("feishu webhook_url is empty")
	}

	signedURL, err := signFeishuWebhook(webhook, strings.TrimSpace(viper.GetString("feishu.secret")))
	if err != nil {
		return fmt.Errorf("sign feishu webhook: %w", err)
	}

	payload := buildFeishuAgentCreatedCard(n)
	raw, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal feishu card: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, signedURL, bytes.NewReader(raw))
	if err != nil {
		return fmt.Errorf("build feishu request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := NewHTTPClient(8).Do(req)
	if err != nil {
		return fmt.Errorf("post feishu webhook: %w", err)
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("feishu webhook http %d: %s", resp.StatusCode, strings.TrimSpace(string(bodyBytes)))
	}

	var bodyMap map[string]interface{}
	if len(bodyBytes) > 0 {
		_ = json.Unmarshal(bodyBytes, &bodyMap)
	}
	if code, ok := numericField(bodyMap, "code"); ok && code != 0 {
		return fmt.Errorf("feishu webhook error code=%d msg=%s", code, stringField(bodyMap, "msg"))
	}
	if code, ok := numericField(bodyMap, "StatusCode"); ok && code != 0 {
		return fmt.Errorf("feishu webhook error code=%d msg=%s", code, stringField(bodyMap, "StatusMessage"))
	}

	return nil
}

func buildFeishuAgentCreatedCard(n FeishuAgentCreatedNotification) map[string]interface{} {
	userName := strings.TrimSpace(n.UserName)
	if userName == "" {
		userName = strings.TrimSpace(n.UserID)
	}
	if userName == "" {
		userName = "unknown"
	}

	createdAt := n.CreatedAt
	if createdAt.IsZero() {
		createdAt = time.Now()
	}

	description := sanitizeCardText(n.Description, 180)
	if description == "" {
		description = "无"
	}

	provider := strings.TrimSpace(n.ProviderProfile)
	if provider == "" {
		provider = "后端内置"
	} else {
		provider = sanitizeCardText(provider, 64)
	}

	body := fmt.Sprintf(
		"**创建者**：%s\n**角色卡**：%s\n**模型**：%s\n**来源**：%s\n**角色卡 ID**：`%s`\n**描述**：%s\n**时间**：%s",
		sanitizeCardText(userName, 64),
		sanitizeCardText(n.AgentName, 64),
		sanitizeCardText(n.ModelName, 64),
		provider,
		sanitizeCardText(n.AgentID, 64),
		description,
		createdAt.Format("2006-01-02 15:04:05"),
	)

	return map[string]interface{}{
		"msg_type": "interactive",
		"card": map[string]interface{}{
			"config": map[string]interface{}{
				"wide_screen_mode": true,
				"enable_forward":   true,
			},
			"header": map[string]interface{}{
				"template": "green",
				"title": map[string]interface{}{
					"tag":     "plain_text",
					"content": "角色卡创建成功",
				},
			},
			"elements": []map[string]interface{}{
				{
					"tag":  "div",
					"text": map[string]interface{}{"tag": "lark_md", "content": body},
				},
				{
					"tag": "note",
					"elements": []map[string]interface{}{
						{
							"tag":     "plain_text",
							"content": "数据库写入完成后发送。",
						},
					},
				},
			},
		},
	}
}

func signFeishuWebhook(rawURL, secret string) (string, error) {
	if secret == "" {
		return rawURL, nil
	}

	u, err := url.Parse(rawURL)
	if err != nil {
		return "", err
	}

	timestamp := strconv.FormatInt(time.Now().Unix(), 10)
	mac := hmac.New(sha256.New, []byte(secret))
	_, _ = mac.Write([]byte(timestamp + "\n" + secret))
	sign := base64.StdEncoding.EncodeToString(mac.Sum(nil))

	q := u.Query()
	q.Set("timestamp", timestamp)
	q.Set("sign", sign)
	u.RawQuery = q.Encode()
	return u.String(), nil
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
