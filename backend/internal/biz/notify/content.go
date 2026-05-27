package notifybiz

import "strings"

const AdminSystemNotificationType = 4

// SystemNotificationContent 合并标题与正文。
func SystemNotificationContent(title, content string) string {
	title = strings.TrimSpace(title)
	content = strings.TrimSpace(content)
	if title != "" && content != "" {
		return title + ": " + content
	}
	if title != "" {
		return title
	}
	return content
}
