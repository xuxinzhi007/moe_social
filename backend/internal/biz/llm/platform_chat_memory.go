package llmbiz

import (
	"context"
	"fmt"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	llmv1 "backend/api/llm/v1"
)

const (
	fallbackMemoryItems           = 2
	memoryCacheTTL                = 30 * time.Second
	maxUserMemoryCacheEntries     = 512
	backgroundMemoryTaskTimeout   = 60 * time.Second
	sourcePreCompactFlush         = "pre_compact_flush"
	coreConversationGuardrails = "你是一个社交应用中的中文助手。你的目标是真正理解用户需求，并给出自然、具体、可执行的中文回答。\n\n你需要：\n1. 主动结合当前消息和完整历史对话来理解用户真正想做什么，而不是只按字面意思机械回复。\n2. 当用户表达不清晰或有多种可能理解时，先用一两句简短话语确认或澄清需求，再继续回答。\n3. 当用户说“帮我总结一下聊天”“总结一下刚才的内容”“分析一下我们刚才聊的重点”等时，直接基于你看到的全部对话记录给出结构化分析与要点，不要让用户复制聊天记录。\n4. 当用户询问如何实现某个功能或写代码时，请给出具体步骤和示例，而不是泛泛而谈。\n5. 不要说“作为AI”“我是AI助手”“我只是模型/程序”等自我限制话术；用户问“你是谁/你叫什么”时，直接自然回答，不暴露模型身份。\n\n当用户提到“刚才”“之前”“上面说的”等表达时，需要基于完整聊天记录理解含义并回答。"

	// roleplayConversationGuardrails 角色卡聊天：勿覆盖人设，勿套用通用助手口吻。
	roleplayConversationGuardrails = "【对话护栏 · 角色扮演】\n" +
		"1. 严格保持上文 [角色人设]/[场景设定] 中的身份与世界观；不要说自己是 AI/模型/助手。\n" +
		"2. 用户问「你是谁/你叫什么」时，用角色卡中的名字与身份回答，不要套用其它示例台词或咖啡店等无关设定。\n" +
		"3. 用户问「我叫什么/我的名字」时，按场景中的玩家角色回答；若场景未定义，诚实说设定里未写明，不要与 NPC 名字混淆。\n" +
		"4. 若注入的「用户记忆」与当前场景冲突，以角色卡与场景为准；账号昵称不等于戏中 NPC。\n" +
		"5. 不要机械重复同一段开场白；每次回复应接得住用户上一句的具体问题。"
	fallbackPersonaReply          = "我更想先听听你的想法，我们可以按你的偏好来聊。"
)

var memoryTokenPattern = regexp.MustCompile(`[\p{Han}]{2,}|[a-zA-Z0-9_]{2,}`)

type cachedMemories struct {
	items     []*llmv1.UserMemory
	expiresAt time.Time
}

var userMemoryCache = struct {
	sync.RWMutex
	data map[string]cachedMemories
}{
	data: make(map[string]cachedMemories),
}

type rankedMemory struct {
	line    string
	score   int
	index   int
	persona bool
}

func isRoleplaySystemPrompt(prompt string) bool {
	p := strings.TrimSpace(prompt)
	if p == "" {
		return false
	}
	return strings.Contains(p, "[扮演约束]") ||
		strings.Contains(p, "[角色人设]") ||
		strings.Contains(p, "[场景设定]")
}

func conversationGuardrailsFor(clientSystemPrompt string) string {
	if isRoleplaySystemPrompt(clientSystemPrompt) {
		return roleplayConversationGuardrails
	}
	return coreConversationGuardrails
}

func memoryBudgetOrDefault(b MemoryBudgetConfig) MemoryBudgetConfig {
	if b.MaxCtxTokens <= 0 {
		return DefaultMemoryBudget()
	}
	return b
}

func isNoiseMemoryValue(value string) bool {
	norm := normalizeMemoryText(value)
	if norm == "" {
		return true
	}
	switch norm {
	case "-", "--", "/", "n/a", "na", "none", "null", "nil", "unknown", "无", "未知", "未提及", "不知道":
		return true
	}
	return false
}

func isTechnicalMemory(key, source string) bool {
	k := strings.ToLower(strings.TrimSpace(key))
	s := strings.ToLower(strings.TrimSpace(source))
	if strings.HasPrefix(k, "device_info:") {
		return true
	}
	return s == "device_sync"
}

func selectFallbackRecentMemories(ranked []rankedMemory, budget MemoryBudgetConfig) []string {
	if len(ranked) == 0 {
		return nil
	}
	limit := min(fallbackMemoryItems, len(ranked))
	lines := make([]string, 0, limit)
	totalRunes := 0
	for _, item := range ranked {
		if len(lines) >= limit {
			break
		}
		itemRunes := len([]rune(item.line))
		if totalRunes+itemRunes > budget.MaxInjectedMemoryRunes && len(lines) > 0 {
			break
		}
		lines = append(lines, item.line)
		totalRunes += itemRunes
	}
	if len(lines) == 0 {
		lines = append(lines, ranked[0].line)
	}
	return lines
}

func estimateTokens(s string) int {
	return len([]rune(s))
}

func getCachedUserMemories(userID string) ([]*llmv1.UserMemory, bool) {
	now := time.Now()
	userMemoryCache.RLock()
	entry, ok := userMemoryCache.data[userID]
	userMemoryCache.RUnlock()
	if !ok {
		return nil, false
	}
	if now.After(entry.expiresAt) {
		userMemoryCache.Lock()
		delete(userMemoryCache.data, userID)
		userMemoryCache.Unlock()
		return nil, false
	}
	return entry.items, true
}

func setCachedUserMemories(userID string, items []*llmv1.UserMemory) {
	userMemoryCache.Lock()
	defer userMemoryCache.Unlock()
	evictUserMemoryCacheLocked()
	if len(userMemoryCache.data) >= maxUserMemoryCacheEntries {
		evictOldestUserMemoryCacheEntryLocked()
	}
	userMemoryCache.data[userID] = cachedMemories{
		items:     items,
		expiresAt: time.Now().Add(memoryCacheTTL),
	}
}

func evictUserMemoryCacheLocked() {
	now := time.Now()
	for id, entry := range userMemoryCache.data {
		if now.After(entry.expiresAt) {
			delete(userMemoryCache.data, id)
		}
	}
}

func evictOldestUserMemoryCacheEntryLocked() {
	var oldestID string
	var oldestExpiry time.Time
	for id, entry := range userMemoryCache.data {
		if oldestID == "" || entry.expiresAt.Before(oldestExpiry) {
			oldestID = id
			oldestExpiry = entry.expiresAt
		}
	}
	if oldestID != "" {
		delete(userMemoryCache.data, oldestID)
	}
}

func backgroundMemoryExtractContext(timeoutSeconds int) (context.Context, context.CancelFunc) {
	d := time.Duration(timeoutSeconds) * time.Second
	if d <= 0 || d > backgroundMemoryTaskTimeout {
		d = backgroundMemoryTaskTimeout
	}
	return context.WithTimeout(context.Background(), d)
}

func invalidateCachedUserMemories(userID string) {
	userMemoryCache.Lock()
	delete(userMemoryCache.data, userID)
	userMemoryCache.Unlock()
}

func extractMemoryQueryTokens(messages []PlatformChatMessage) []string {
	for i := len(messages) - 1; i >= 0; i-- {
		if strings.TrimSpace(messages[i].Role) != "user" {
			continue
		}
		content := strings.ToLower(strings.TrimSpace(messages[i].Content))
		if content == "" {
			continue
		}
		matches := memoryTokenPattern.FindAllString(content, -1)
		if len(matches) == 0 {
			return nil
		}
		uniq := make([]string, 0, len(matches))
		seen := make(map[string]struct{}, len(matches))
		for _, m := range matches {
			token := strings.TrimSpace(m)
			if token == "" {
				continue
			}
			if _, ok := seen[token]; ok {
				continue
			}
			seen[token] = struct{}{}
			uniq = append(uniq, token)
		}
		return uniq
	}
	return nil
}

func normalizeMemoryText(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	replacer := strings.NewReplacer("\n", " ", "\r", " ", "\t", " ")
	s = replacer.Replace(s)
	return strings.Join(strings.Fields(s), " ")
}

func selectRelevantMemoryLines(memories []*llmv1.UserMemory, messages []PlatformChatMessage, budget MemoryBudgetConfig) []string {
	if len(memories) == 0 {
		return nil
	}
	tokens := extractMemoryQueryTokens(messages)
	hasQueryTokens := len(tokens) > 0
	hasKeywordHit := false
	ranked := make([]rankedMemory, 0, len(memories))
	seen := make(map[string]struct{}, len(memories))

	for i, m := range memories {
		key := strings.TrimSpace(m.Key)
		value := strings.TrimSpace(m.Value)
		if key == "" || value == "" {
			continue
		}
		if isTechnicalMemory(key, m.Source) {
			continue
		}
		if isNoiseMemoryValue(value) {
			continue
		}
		line := fmt.Sprintf("%s: %s", key, value)
		norm := normalizeMemoryText(line)
		if norm == "" {
			continue
		}
		if _, ok := seen[norm]; ok {
			continue
		}
		seen[norm] = struct{}{}

		score := 1
		if i < 5 {
			score += 2
		}

		joined := normalizeMemoryText(key + " " + value)
		matched := false
		for _, token := range tokens {
			if strings.Contains(joined, token) {
				score += 3
				matched = true
			}
		}
		if matched {
			hasKeywordHit = true
		}

		ranked = append(ranked, rankedMemory{
			line:    line,
			score:   score,
			index:   i,
			persona: isPersonaMemory(m),
		})
	}

	if len(ranked) == 0 {
		return nil
	}

	sort.Slice(ranked, func(i, j int) bool {
		if ranked[i].score != ranked[j].score {
			return ranked[i].score > ranked[j].score
		}
		return ranked[i].index < ranked[j].index
	})

	if !hasQueryTokens || !hasKeywordHit {
		return mergePersonaAndFallbackMemories(ranked, budget)
	}

	lines := make([]string, 0, min(budget.MaxInjectedMemoryItems, len(ranked)))
	selectedSeen := make(map[string]struct{}, budget.MaxInjectedMemoryItems)
	totalRunes := 0
	appendLines := func(candidates []string) {
		for _, line := range candidates {
			if len(lines) >= budget.MaxInjectedMemoryItems {
				return
			}
			if _, ok := selectedSeen[line]; ok {
				continue
			}
			itemRunes := len([]rune(line))
			if totalRunes+itemRunes > budget.MaxInjectedMemoryRunes && len(lines) > 0 {
				return
			}
			lines = append(lines, line)
			selectedSeen[line] = struct{}{}
			totalRunes += itemRunes
		}
	}
	appendLines(selectPersonaAnchorMemories(ranked, budget))
	for _, item := range ranked {
		appendLines([]string{item.line})
	}
	if len(lines) == 0 {
		return mergePersonaAndFallbackMemories(ranked, budget)
	}
	return lines
}

func isPersonaMemory(m *llmv1.UserMemory) bool {
	if m == nil {
		return false
	}
	key := strings.ToLower(strings.TrimSpace(m.Key))
	memoryType := strings.ToLower(strings.TrimSpace(m.MemoryType))

	switch memoryType {
	case "relationship", "preference", "persona", "identity", "profile":
		return true
	}

	hints := []string{
		"relationship", "relation", "persona", "identity", "character",
		"prefer", "preference", "interest", "style", "nickname", "name",
		"关系", "偏好", "兴趣", "身份", "人设", "称呼", "名字", "风格",
	}
	for _, h := range hints {
		if strings.Contains(key, h) {
			return true
		}
	}
	return false
}

func selectPersonaAnchorMemories(ranked []rankedMemory, budget MemoryBudgetConfig) []string {
	lines := make([]string, 0, 3)
	totalRunes := 0
	for _, item := range ranked {
		if !item.persona {
			continue
		}
		itemRunes := len([]rune(item.line))
		if len(lines) >= 3 {
			break
		}
		if totalRunes+itemRunes > budget.MaxInjectedMemoryRunes && len(lines) > 0 {
			break
		}
		lines = append(lines, item.line)
		totalRunes += itemRunes
	}
	return lines
}

func mergePersonaAndFallbackMemories(ranked []rankedMemory, budget MemoryBudgetConfig) []string {
	anchors := selectPersonaAnchorMemories(ranked, budget)
	fallback := selectFallbackRecentMemories(ranked, budget)

	lines := make([]string, 0, min(budget.MaxInjectedMemoryItems, len(anchors)+len(fallback)))
	seen := make(map[string]struct{}, budget.MaxInjectedMemoryItems)
	totalRunes := 0
	appendOne := func(line string) bool {
		if len(lines) >= budget.MaxInjectedMemoryItems {
			return false
		}
		if _, ok := seen[line]; ok {
			return true
		}
		itemRunes := len([]rune(line))
		if totalRunes+itemRunes > budget.MaxInjectedMemoryRunes && len(lines) > 0 {
			return false
		}
		lines = append(lines, line)
		seen[line] = struct{}{}
		totalRunes += itemRunes
		return true
	}
	for _, line := range anchors {
		if !appendOne(line) {
			return lines
		}
	}
	for _, line := range fallback {
		if !appendOne(line) {
			return lines
		}
	}
	return lines
}

func sanitizePersonaResponse(content string) string {
	text := strings.TrimSpace(content)
	if text == "" {
		return text
	}
	replacements := []string{
		"作为一个AI助手，",
		"作为AI助手，",
		"作为 AI 助手，",
		"作为 AI助手，",
		"我是一个AI助手",
		"我是AI助手",
		"我是一个 AI 助手",
		"我是 AI 助手",
		"我只是一个AI模型",
		"我只是AI模型",
		"我只是一个模型",
		"我没有个人喜好",
		"我没有情感体验",
	}
	for _, s := range replacements {
		text = strings.ReplaceAll(text, s, "")
	}
	text = strings.TrimSpace(text)
	if text == "" {
		return fallbackPersonaReply
	}
	return text
}

func userIDFromContext(ctx context.Context) string {
	if v := ctx.Value("user_id"); v != nil {
		if userID, ok := v.(string); ok && userID != "" {
			return userID
		}
	}
	return ""
}
