package companionbiz

import "strings"

var unfinishedTopicMarkers = []string{
	"下次",
	"之后",
	"以后",
	"继续",
	"还没",
	"未完",
	"计划",
	"准备",
	"打算",
	"todo",
	"follow up",
}

func extractUnfinishedTopics(history []ChatLog) []string {
	seen := make(map[string]struct{})
	topics := make([]string, 0, 3)
	for index := len(history) - 1; index >= 0 && len(topics) < 3; index-- {
		entry := history[index]
		if entry.Role != "user" {
			continue
		}
		content := strings.TrimSpace(entry.Content)
		if content == "" || !containsUnfinishedTopicMarker(content) {
			continue
		}
		content = clipTopic(content, 120)
		key := strings.ToLower(content)
		if _, exists := seen[key]; exists {
			continue
		}
		seen[key] = struct{}{}
		topics = append(topics, content)
	}
	return topics
}

func containsUnfinishedTopicMarker(content string) bool {
	normalized := strings.ToLower(strings.TrimSpace(content))
	for _, marker := range unfinishedTopicMarkers {
		if strings.Contains(normalized, marker) {
			return true
		}
	}
	return false
}

func clipTopic(content string, maxRunes int) string {
	runes := []rune(strings.TrimSpace(content))
	if len(runes) <= maxRunes {
		return string(runes)
	}
	return strings.TrimSpace(string(runes[:maxRunes])) + "…"
}
