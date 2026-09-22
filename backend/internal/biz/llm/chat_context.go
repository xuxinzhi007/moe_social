package llmbiz

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	aibiz "backend/internal/biz/ai"
	"backend/model"
)

const defaultAgentSystemPrompt = "你正在进行角色扮演对话。请完全以角色身份回应，保持口吻、价值观和行为方式一致。"

type chatAgentCard struct {
	ID               string
	ModelName        string
	SystemPrompt     string
	Persona          string
	Scenario         string
	ExampleDialogues string
	LorebookID       string
}

type chatLorebookEntry struct {
	Title         string
	Content       string
	Keywords      []string
	Enabled       bool
	AlwaysEnabled bool
	Priority      int
	UpdatedAt     int64
}

// ApplyAgentChatContext loads backend-owned agent prompt context into chat input.
func ApplyAgentChatContext(cfg *model.AiUserConfig, in PlatformChatInput) (PlatformChatInput, error) {
	agentID := strings.TrimSpace(in.AgentID)
	if agentID == "" {
		return in, nil
	}
	if cfg == nil {
		return in, llmError(404, "角色卡不存在")
	}
	agent, ok := findChatAgent(cfg.AgentsJSON, agentID)
	if !ok {
		return in, llmError(404, "角色卡不存在")
	}
	if agent.ModelName != "" {
		in.Model = agent.ModelName
	}
	systemPrompt := buildAgentSystemPrompt(agent, strings.TrimSpace(cfg.UserPersona), matchedLorebookEntries(
		cfg.LorebooksJSON,
		agent.LorebookID,
		chatContextText(in.Messages),
	))
	in.Messages = prependSystemMessage(in.Messages, systemPrompt)
	in.ClientMemoryApplied = false
	return in, nil
}

func findChatAgent(raw string, id string) (chatAgentCard, bool) {
	for _, item := range aibiz.DecodeJSONArray(raw) {
		if strings.TrimSpace(fmt.Sprint(item["id"])) != id {
			continue
		}
		return chatAgentCard{
			ID:               id,
			ModelName:        aibiz.StringValue(item["model_name"]),
			SystemPrompt:     aibiz.StringValue(item["system_prompt"]),
			Persona:          aibiz.StringValue(item["persona"]),
			Scenario:         aibiz.StringValue(item["scenario"]),
			ExampleDialogues: aibiz.StringValue(item["example_dialogues"]),
			LorebookID:       aibiz.StringValue(item["lorebook_id"]),
		}, true
	}
	return chatAgentCard{}, false
}

func buildAgentSystemPrompt(agent chatAgentCard, userPersona string, lorebookEntries []chatLorebookEntry) string {
	basePrompt := strings.TrimSpace(agent.SystemPrompt)
	if basePrompt == "" {
		basePrompt = defaultAgentSystemPrompt
	}
	var out strings.Builder
	out.WriteString(basePrompt)
	if agent.Persona != "" {
		out.WriteString("\n\n[角色人设]\n")
		out.WriteString(agent.Persona)
	}
	if agent.Scenario != "" {
		out.WriteString("\n\n[场景设定]\n")
		out.WriteString(agent.Scenario)
	}
	if agent.ExampleDialogues != "" {
		out.WriteString("\n\n[示例对话风格]\n")
		out.WriteString(agent.ExampleDialogues)
	}
	if userPersona != "" {
		out.WriteString("\n\n[用户 Persona]\n")
		out.WriteString(userPersona)
	}
	if len(lorebookEntries) > 0 {
		out.WriteString("\n\n")
		out.WriteString(renderLorebookSection(lorebookEntries))
	}
	out.WriteString("\n\n[扮演约束]\n")
	out.WriteString("1. 你就是这个角色本人，不是在「描述」或「模拟」角色；用第一人称沉浸回应。\n")
	out.WriteString("2. 禁止说自己是 AI/模型/助手，禁止用政策式拒答；遇限制时用角色口吻绕开或转移话题。\n")
	out.WriteString("3. 保持语气、用词、知识与世界观一致；用户未要求 OOC 时不要跳出设定。\n")
	out.WriteString("4. 优先接住用户情绪与意图，再推进对话，避免机械重复上述规则。")
	if !roleplayStyle(agent) {
		out.WriteString("\n\n补充硬性规则：\n")
		out.WriteString("1) 不要说“作为AI”“我是AI助手”“我只是模型/程序”等自我限制话术。\n")
		out.WriteString("2) 用户问“你是谁/你叫什么”时，直接以自然人格化口吻回答，不要暴露模型身份。")
	}
	return strings.TrimSpace(out.String())
}

func roleplayStyle(agent chatAgentCard) bool {
	return agent.Persona != "" || agent.Scenario != "" || agent.ExampleDialogues != ""
}

func prependSystemMessage(messages []PlatformChatMessage, prompt string) []PlatformChatMessage {
	next := make([]PlatformChatMessage, 0, len(messages)+1)
	next = append(next, PlatformChatMessage{Role: "system", Content: prompt})
	for _, message := range messages {
		if strings.TrimSpace(message.Role) == "system" {
			continue
		}
		next = append(next, message)
	}
	return next
}

func chatContextText(messages []PlatformChatMessage) string {
	parts := make([]string, 0, len(messages))
	for _, message := range messages {
		if strings.TrimSpace(message.Content) != "" {
			parts = append(parts, message.Content)
		}
	}
	return strings.ToLower(strings.Join(parts, "\n"))
}

func matchedLorebookEntries(raw string, lorebookID string, contextText string) []chatLorebookEntry {
	if strings.TrimSpace(lorebookID) == "" {
		return nil
	}
	entries := lorebookEntries(raw, lorebookID)
	matched := make([]chatLorebookEntry, 0, len(entries))
	for _, entry := range entries {
		if !entry.Enabled || strings.TrimSpace(entry.Content) == "" {
			continue
		}
		if entry.AlwaysEnabled || keywordsMatch(entry.Keywords, contextText) {
			matched = append(matched, entry)
		}
	}
	sort.SliceStable(matched, func(i, j int) bool {
		if matched[i].AlwaysEnabled != matched[j].AlwaysEnabled {
			return matched[i].AlwaysEnabled
		}
		if matched[i].Priority != matched[j].Priority {
			return matched[i].Priority > matched[j].Priority
		}
		return matched[i].UpdatedAt > matched[j].UpdatedAt
	})
	return trimLorebookEntries(matched, 8, 2400)
}

func lorebookEntries(raw string, lorebookID string) []chatLorebookEntry {
	for _, item := range aibiz.DecodeJSONArray(raw) {
		if strings.TrimSpace(fmt.Sprint(item["id"])) != lorebookID {
			continue
		}
		rawEntries, ok := item["entries"].([]interface{})
		if !ok {
			return nil
		}
		out := make([]chatLorebookEntry, 0, len(rawEntries))
		for _, rawEntry := range rawEntries {
			entryMap, ok := rawEntry.(map[string]interface{})
			if !ok {
				continue
			}
			out = append(out, parseLorebookEntry(entryMap))
		}
		return out
	}
	return nil
}

func parseLorebookEntry(item map[string]interface{}) chatLorebookEntry {
	return chatLorebookEntry{
		Title:         aibiz.StringValue(item["title"]),
		Content:       aibiz.StringValue(item["content"]),
		Keywords:      parseKeywords(item["keywords_json"]),
		Enabled:       boolValue(item["enabled"], true),
		AlwaysEnabled: boolValue(item["always_enabled"], false),
		Priority:      intValue(item["priority"], 50),
		UpdatedAt:     int64(intValue(item["updated_at"], 0)),
	}
}

func parseKeywords(raw interface{}) []string {
	switch value := raw.(type) {
	case []interface{}:
		out := make([]string, 0, len(value))
		for _, item := range value {
			if keyword := strings.TrimSpace(fmt.Sprint(item)); keyword != "" {
				out = append(out, keyword)
			}
		}
		return out
	case string:
		var decoded []string
		if err := json.Unmarshal([]byte(value), &decoded); err == nil {
			out := make([]string, 0, len(decoded))
			for _, keyword := range decoded {
				if keyword = strings.TrimSpace(keyword); keyword != "" {
					out = append(out, keyword)
				}
			}
			return out
		}
		return nil
	default:
		return nil
	}
}

func boolValue(raw interface{}, fallback bool) bool {
	switch value := raw.(type) {
	case bool:
		return value
	case float64:
		return value != 0
	case int:
		return value != 0
	case string:
		normalized := strings.TrimSpace(strings.ToLower(value))
		return normalized == "true" || normalized == "1" || normalized == "yes"
	default:
		return fallback
	}
}

func intValue(raw interface{}, fallback int) int {
	switch value := raw.(type) {
	case int:
		return value
	case int64:
		return int(value)
	case float64:
		return int(value)
	case json.Number:
		if n, err := value.Int64(); err == nil {
			return int(n)
		}
	default:
		return fallback
	}
	return fallback
}

func keywordsMatch(keywords []string, contextText string) bool {
	if strings.TrimSpace(contextText) == "" {
		return false
	}
	for _, keyword := range keywords {
		if keyword = strings.TrimSpace(strings.ToLower(keyword)); keyword != "" && strings.Contains(contextText, keyword) {
			return true
		}
	}
	return false
}

func trimLorebookEntries(entries []chatLorebookEntry, maxEntries int, maxChars int) []chatLorebookEntry {
	out := make([]chatLorebookEntry, 0, len(entries))
	totalChars := 0
	for _, entry := range entries {
		rendered := renderLorebookEntry(entry)
		if rendered == "" {
			continue
		}
		nextChars := totalChars + len([]rune(rendered))
		if len(out) > 0 && (len(out) >= maxEntries || nextChars > maxChars) {
			break
		}
		out = append(out, entry)
		totalChars = nextChars
		if len(out) >= maxEntries {
			break
		}
	}
	return out
}

func renderLorebookSection(entries []chatLorebookEntry) string {
	var out strings.Builder
	out.WriteString("[世界书设定]\n以下设定在当前对话中生效，请自然遵守和引用，不要机械逐条复述规则。")
	for _, entry := range entries {
		rendered := renderLorebookEntry(entry)
		if rendered == "" {
			continue
		}
		out.WriteString("\n\n")
		out.WriteString(rendered)
	}
	return strings.TrimSpace(out.String())
}

func renderLorebookEntry(entry chatLorebookEntry) string {
	content := strings.TrimSpace(entry.Content)
	if content == "" {
		return ""
	}
	title := strings.TrimSpace(entry.Title)
	if title == "" {
		title = "设定"
	}
	return "[" + title + "]\n" + content
}
