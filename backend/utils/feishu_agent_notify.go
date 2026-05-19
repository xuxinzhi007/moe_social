package utils

import (
	"context"
	"fmt"
	"strings"
	"time"
)

// FeishuAgentAction 角色卡飞书通知类型。
type FeishuAgentAction string

const (
	FeishuAgentCreated FeishuAgentAction = "created"
	FeishuAgentUpdated FeishuAgentAction = "updated"
	FeishuAgentDeleted FeishuAgentAction = "deleted"
)

// FeishuAgentEvent 角色卡变更事件（创建 / 更新 / 删除）。
type FeishuAgentEvent struct {
	Action          FeishuAgentAction
	UserName        string
	UserID          string
	AgentID         string
	AgentName       string
	Description     string
	ModelName       string
	ProviderProfile string
	EventAt         time.Time
}

// SendFeishuAgentEventNotification 向用户绑定邮箱或运营默认收件人发送卡片。
func SendFeishuAgentEventNotification(ctx context.Context, e FeishuAgentEvent, recipientEmail string) error {
	receiveID, receiveIDType, err := resolveFeishuRecipient(recipientEmail)
	if err != nil {
		return err
	}
	return sendFeishuInteractiveCard(ctx, receiveIDType, receiveID, buildFeishuAgentEventCard(e))
}

func buildFeishuAgentEventCard(e FeishuAgentEvent) map[string]interface{} {
	action := e.Action
	if action == "" {
		action = FeishuAgentCreated
	}

	userName := firstNonEmpty(strings.TrimSpace(e.UserName), strings.TrimSpace(e.UserID), "unknown")
	eventAt := e.EventAt
	if eventAt.IsZero() {
		eventAt = time.Now()
	}

	description := sanitizeCardText(e.Description, 180)
	if description == "" {
		description = "无"
	}

	provider := strings.TrimSpace(e.ProviderProfile)
	if provider == "" {
		provider = "后端内置"
	} else {
		provider = sanitizeCardText(provider, 64)
	}

	title, template, note := feishuAgentActionMeta(action)
	body := fmt.Sprintf(
		"**操作者**：%s\n**角色卡**：%s\n**模型**：%s\n**来源**：%s\n**角色卡 ID**：`%s`\n**描述**：%s\n**时间**：%s",
		sanitizeCardText(userName, 64),
		sanitizeCardText(e.AgentName, 64),
		sanitizeCardText(e.ModelName, 64),
		provider,
		sanitizeCardText(e.AgentID, 64),
		description,
		eventAt.Format("2006-01-02 15:04:05"),
	)

	return map[string]interface{}{
		"config": map[string]interface{}{
			"wide_screen_mode": true,
			"enable_forward":   true,
		},
		"header": map[string]interface{}{
			"template": template,
			"title": map[string]interface{}{
				"tag":     "plain_text",
				"content": title,
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
						"content": note,
					},
				},
			},
		},
	}
}

func feishuAgentActionMeta(action FeishuAgentAction) (title, template, note string) {
	switch action {
	case FeishuAgentUpdated:
		return "角色卡已更新", "blue", "用户更新了角色卡配置（自建应用机器人）。"
	case FeishuAgentDeleted:
		return "角色卡已删除", "red", "用户删除了角色卡（自建应用机器人）。"
	default:
		return "角色卡创建成功", "green", "用户新建了角色卡（自建应用机器人）。"
	}
}

func firstNonEmpty(parts ...string) string {
	for _, p := range parts {
		if strings.TrimSpace(p) != "" {
			return strings.TrimSpace(p)
		}
	}
	return ""
}
