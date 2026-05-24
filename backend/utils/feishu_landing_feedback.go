package utils

import (
	"context"
	"fmt"
	"strings"
	"time"
)

// LandingFeedbackNotification 官网意见反馈飞书卡片载荷。
type LandingFeedbackNotification struct {
	ID        uint
	Email     string
	Category  string
	Content   string
	Source    string
	ClientIP  string
	CreatedAt time.Time
}

// SendFeishuLandingFeedbackNotification 通知运营收件人（config feishu.receive_id）。
func SendFeishuLandingFeedbackNotification(ctx context.Context, n LandingFeedbackNotification) error {
	receiveID, receiveIDType, err := resolveFeishuRecipient("")
	if err != nil {
		return err
	}
	return sendFeishuInteractiveCard(ctx, receiveIDType, receiveID, buildLandingFeedbackCard(n))
}

func buildLandingFeedbackCard(n LandingFeedbackNotification) map[string]interface{} {
	categoryLabel := landingFeedbackCategoryLabel(n.Category)
	email := sanitizeCardText(n.Email, 80)
	if email == "" {
		email = "未填写"
	}
	content := sanitizeCardText(n.Content, 500)
	if content == "" {
		content = "（无内容）"
	}
	source := sanitizeCardText(n.Source, 48)
	if source == "" {
		source = "official-site"
	}
	eventAt := n.CreatedAt
	if eventAt.IsZero() {
		eventAt = time.Now()
	}
	ip := strings.TrimSpace(n.ClientIP)
	if ip == "" {
		ip = "-"
	}

	body := fmt.Sprintf(
		"**类型**：%s\n**联系邮箱**：%s\n**来源**：%s\n**IP**：%s\n**反馈 ID**：%d\n**时间**：%s\n\n**内容**：\n%s",
		categoryLabel,
		email,
		source,
		ip,
		n.ID,
		eventAt.Format("2006-01-02 15:04:05"),
		content,
	)

	return map[string]interface{}{
		"config": map[string]interface{}{
			"wide_screen_mode": true,
			"enable_forward":   true,
		},
		"header": map[string]interface{}{
			"title": map[string]interface{}{
				"tag":     "plain_text",
				"content": "Moe Social · 官网新反馈",
			},
			"template": "wathet",
		},
		"elements": []interface{}{
			map[string]interface{}{
				"tag": "div",
				"text": map[string]interface{}{
					"tag":     "lark_md",
					"content": body,
				},
			},
		},
	}
}

func landingFeedbackCategoryLabel(category string) string {
	switch strings.ToLower(strings.TrimSpace(category)) {
	case "feature":
		return "功能建议"
	case "bug":
		return "问题反馈"
	default:
		return "其他"
	}
}
