package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

const (
	maxCtxTokens       = 4096
	maxHistoryMessages = 40
	keepRecentMessages = 16
	// 记忆注入上限：避免无关记忆挤占上下文窗口。
	maxInjectedMemoryItems = 8
	maxInjectedMemoryRunes = 520
	fallbackMemoryItems    = 2
	memoryCacheTTL         = 30 * time.Second
)

const coreConversationGuardrails = "你是一个社交应用中的中文助手。你的目标是真正理解用户需求，并给出自然、具体、可执行的中文回答。\n\n你需要：\n1. 主动结合当前消息和完整历史对话来理解用户真正想做什么，而不是只按字面意思机械回复。\n2. 当用户表达不清晰或有多种可能理解时，先用一两句简短话语确认或澄清需求，再继续回答。\n3. 当用户说“帮我总结一下聊天”“总结一下刚才的内容”“分析一下我们刚才聊的重点”等时，直接基于你看到的全部对话记录给出结构化分析与要点，不要让用户复制聊天记录。\n4. 当用户询问如何实现某个功能或写代码时，请给出具体步骤和示例，而不是泛泛而谈。\n5. 不要说“作为AI”“我是AI助手”“我只是模型/程序”等自我限制话术；用户问“你是谁/你叫什么”时，直接自然回答，不暴露模型身份。\n\n当用户提到“刚才”“之前”“上面说的”等表达时，需要基于完整聊天记录理解含义并回答。"
const fallbackPersonaReply = "我更想先听听你的想法，我们可以按你的偏好来聊。"

var ctxSafeRatio = 0.7
var memoryTokenPattern = regexp.MustCompile(`[\p{Han}]{2,}|[a-zA-Z0-9_]{2,}`)

type cachedMemories struct {
	items     []*super.UserMemory
	expiresAt time.Time
}

var userMemoryCache = struct {
	sync.RWMutex
	data map[string]cachedMemories
}{
	data: make(map[string]cachedMemories),
}

type ollamaMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ollamaRequest struct {
	Model         string          `json:"model"`
	Messages      []ollamaMessage `json:"messages"`
	Stream        bool            `json:"stream"`
	Temperature   float64         `json:"temperature,omitempty"`
	TopP          float64         `json:"top_p,omitempty"`
	MaxTokens     int             `json:"max_tokens,omitempty"`
	RepeatPenalty float64         `json:"repeat_penalty,omitempty"`
}

type ollamaResponse struct {
	Message struct {
		Role    string `json:"role"`
		Content string `json:"content"`
	} `json:"message"`
	PromptEvalCount int `json:"prompt_eval_count"`
	EvalCount       int `json:"eval_count"`
}

type rankedMemory struct {
	line  string
	score int
	index int
	// 人格化记忆锚点：关系/偏好/身份等，优先保留以增强角色一致性。
	persona bool
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
	if s == "device_sync" {
		return true
	}
	return false
}

func selectFallbackRecentMemories(ranked []rankedMemory) []string {
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
		if totalRunes+itemRunes > maxInjectedMemoryRunes && len(lines) > 0 {
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

func getCachedUserMemories(userID string) ([]*super.UserMemory, bool) {
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

func setCachedUserMemories(userID string, items []*super.UserMemory) {
	userMemoryCache.Lock()
	userMemoryCache.data[userID] = cachedMemories{
		items:     items,
		expiresAt: time.Now().Add(memoryCacheTTL),
	}
	userMemoryCache.Unlock()
}

func invalidateCachedUserMemories(userID string) {
	userMemoryCache.Lock()
	delete(userMemoryCache.data, userID)
	userMemoryCache.Unlock()
}

type ChatLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewChatLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ChatLogic {
	return &ChatLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func extractMemoryQueryTokens(messages []types.LlmMessage) []string {
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

func selectRelevantMemoryLines(memories []*super.UserMemory, messages []types.LlmMessage) []string {
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
		// 最近记忆（按 updated_at desc）给基础加权。
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

	// 没有明显关键词命中时，回退注入少量最近记忆，减少噪声和 token 消耗。
	if !hasQueryTokens || !hasKeywordHit {
		return mergePersonaAndFallbackMemories(ranked)
	}

	// 有关键词命中时，也优先保留少量人格锚点，再补齐相关项。
	lines := make([]string, 0, min(maxInjectedMemoryItems, len(ranked)))
	selectedSeen := make(map[string]struct{}, maxInjectedMemoryItems)
	totalRunes := 0
	appendLines := func(candidates []string) {
		for _, line := range candidates {
			if len(lines) >= maxInjectedMemoryItems {
				return
			}
			if _, ok := selectedSeen[line]; ok {
				continue
			}
			itemRunes := len([]rune(line))
			if totalRunes+itemRunes > maxInjectedMemoryRunes && len(lines) > 0 {
				return
			}
			lines = append(lines, line)
			selectedSeen[line] = struct{}{}
			totalRunes += itemRunes
		}
	}
	appendLines(selectPersonaAnchorMemories(ranked))
	for _, item := range ranked {
		appendLines([]string{item.line})
	}
	if len(lines) == 0 {
		return mergePersonaAndFallbackMemories(ranked)
	}
	return lines
}

func isPersonaMemory(m *super.UserMemory) bool {
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

func selectPersonaAnchorMemories(ranked []rankedMemory) []string {
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
		if totalRunes+itemRunes > maxInjectedMemoryRunes && len(lines) > 0 {
			break
		}
		lines = append(lines, item.line)
		totalRunes += itemRunes
	}
	return lines
}

func mergePersonaAndFallbackMemories(ranked []rankedMemory) []string {
	anchors := selectPersonaAnchorMemories(ranked)
	fallback := selectFallbackRecentMemories(ranked)

	lines := make([]string, 0, min(maxInjectedMemoryItems, len(anchors)+len(fallback)))
	seen := make(map[string]struct{}, maxInjectedMemoryItems)
	totalRunes := 0
	appendOne := func(line string) bool {
		if len(lines) >= maxInjectedMemoryItems {
			return false
		}
		if _, ok := seen[line]; ok {
			return true
		}
		itemRunes := len([]rune(line))
		if totalRunes+itemRunes > maxInjectedMemoryRunes && len(lines) > 0 {
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

func (l *ChatLogic) Chat(req *types.LlmChatReq) (resp *types.LlmChatResp, err error) {
	sessionID := strings.TrimSpace(req.SessionId)
	sourceMsgID := strings.TrimSpace(req.SourceMsgId)
	var memoryLines []string
	var userIDForLog string
	if v := l.ctx.Value("user_id"); v != nil {
		if userID, ok := v.(string); ok && userID != "" {
			userIDForLog = userID
			if cached, hit := getCachedUserMemories(userID); hit {
				memoryLines = selectRelevantMemoryLines(cached, req.Messages)
				l.Infof("memory cache hit user_id=%s total=%d selected=%d", userID, len(cached), len(memoryLines))
			} else {
				rpcResp, err := l.svcCtx.SuperRpcClient.GetUserMemories(l.ctx, &super.GetUserMemoriesReq{
					UserId: userID,
				})
				if err != nil {
					l.Errorf("GetUserMemories failed: %v", err)
				} else {
					setCachedUserMemories(userID, rpcResp.Memories)
					memoryLines = selectRelevantMemoryLines(rpcResp.Memories, req.Messages)
					l.Infof("memory cache miss user_id=%s total=%d selected=%d", userID, len(rpcResp.Memories), len(memoryLines))
				}
			}
		}
	}

	// Check if client provided a system prompt
	var clientSystemPrompt string
	var clientSystemIndex = -1
	for i, m := range req.Messages {
		if m.Role == "system" {
			clientSystemPrompt = m.Content
			clientSystemIndex = i
			break
		}
	}

	var systemContent string
	if clientSystemPrompt != "" {
		systemContent = strings.TrimSpace(clientSystemPrompt) + "\n\n" + coreConversationGuardrails
	} else {
		systemContent = coreConversationGuardrails
	}

	if len(memoryLines) > 0 {
		systemContent = systemContent + "\n\n用户的长期背景与偏好信息如下，请在回答时适当参考：\n- " + strings.Join(memoryLines, "\n- ")
	}

	messages := make([]ollamaMessage, 0, len(req.Messages)+1)

	messages = append(messages, ollamaMessage{
		Role:    "system",
		Content: systemContent,
	})

	for i, m := range req.Messages {
		if i == clientSystemIndex {
			continue
		}
		messages = append(messages, ollamaMessage{
			Role:    m.Role,
			Content: m.Content,
		})
	}

	if userIDForLog != "" {
		l.Infof("llm chat with memory, user_id=%s, model=%s, messages=%d, memory_lines=%d", userIDForLog, req.Model, len(req.Messages), len(memoryLines))
	} else {
		l.Infof("llm chat without memory, model=%s, messages=%d", req.Model, len(req.Messages))
	}

	timeoutSeconds := l.svcCtx.Config.Ollama.TimeoutSeconds
	if timeoutSeconds <= 0 {
		timeoutSeconds = 60
	}

	baseUrl, err := common.ResolveOllamaBaseURL(l.svcCtx.Config.Ollama.BaseUrl)
	if err != nil {
		return &types.LlmChatResp{
			BaseResp:       common.HandleError(err),
			Content:        "",
			RemainingRatio: 1,
			Summarized:     false,
		}, nil
	}

	client := utils.NewHTTPClient(timeoutSeconds)

	memoryModel := strings.TrimSpace(l.svcCtx.Config.Ollama.MemoryModel)
	if memoryModel == "" {
		memoryModel = req.Model
	}

	usedTokens := 0
	for _, m := range messages {
		usedTokens += estimateTokens(m.Content)
	}

	usableTokens := int(float64(maxCtxTokens) * ctxSafeRatio)
	if usableTokens <= 0 {
		usableTokens = maxCtxTokens
	}

	needsSummary := false
	if len(req.Messages) > 0 {
		last := req.Messages[len(req.Messages)-1]
		content := strings.TrimSpace(last.Content)
		if content != "" {
			if len([]rune(content)) <= 30 {
				if content == "总结" || content == "概括" || content == "梳理" {
					needsSummary = true
				} else {
					keywords := []string{"总结一下", "帮我总结", "整理一下", "帮我整理", "概括一下", "帮我概括", "梳理一下", "帮我梳理"}
					for _, kw := range keywords {
						if strings.Contains(content, kw) {
							needsSummary = true
							break
						}
					}
				}
			}
		}
	}

	if needsSummary {
		history := messages[1:]
		summary, sumErr := l.summarizeMessages(memoryModel, baseUrl, timeoutSeconds, client, history)
		if sumErr == nil && strings.TrimSpace(summary) != "" {
			if userIDForLog != "" {
				fullMessages := make([]ollamaMessage, len(messages)+1)
				copy(fullMessages, messages)
				fullMessages[len(messages)] = ollamaMessage{
					Role:    "assistant",
					Content: summary,
				}

				go func(uid, model, baseUrl, sid, msgID string, timeout int, msgs []ollamaMessage) {
					bgCtx := context.Background()
					l.extractAndSaveMemories(bgCtx, uid, model, baseUrl, timeout, sid, msgID, msgs)
				}(userIDForLog, memoryModel, baseUrl, sessionID, sourceMsgID, timeoutSeconds, fullMessages)
			}

			usedTokens = 0
			for _, m := range history {
				usedTokens += estimateTokens(m.Content)
			}
			usedTokens += estimateTokens(summary)

			remainingRatio := 1.0
			if usableTokens > 0 {
				remaining := usableTokens - usedTokens
				if remaining < 0 {
					remaining = 0
				}
				if remaining > usableTokens {
					remaining = usableTokens
				}
				remainingRatio = float64(remaining) / float64(usableTokens)
			}

			return &types.LlmChatResp{
				BaseResp:       common.HandleError(nil),
				Content:        summary,
				RemainingRatio: remainingRatio,
				Summarized:     true,
			}, nil
		}
	}

	summarized := false

	needAutoSummary := false
	if len(req.Messages) > maxHistoryMessages {
		needAutoSummary = true
	}
	if !needAutoSummary && usableTokens > 0 && usedTokens > usableTokens && len(messages) > 1+keepRecentMessages {
		needAutoSummary = true
	}

	if needAutoSummary && len(messages) > 1+keepRecentMessages {
		oldEnd := len(messages) - keepRecentMessages
		if oldEnd <= 1 {
			oldEnd = 1
		}
		oldMessages := make([]ollamaMessage, oldEnd-1)
		copy(oldMessages, messages[1:oldEnd])

		summary, sumErr := l.summarizeMessages(memoryModel, baseUrl, timeoutSeconds, client, oldMessages)
		if sumErr != nil {
			l.Errorf("summarizeMessages failed: %v", sumErr)
		} else if strings.TrimSpace(summary) != "" {
			systemContent = systemContent + "\n\n之前部分对话的简要总结如下，请在理解用户当前消息时一并参考：\n" + summary
			newMessages := make([]ollamaMessage, 0, keepRecentMessages+1)
			newMessages = append(newMessages, ollamaMessage{
				Role:    "system",
				Content: systemContent,
			})
			newMessages = append(newMessages, messages[oldEnd:]...)
			messages = newMessages
			summarized = true
		}
	}

	// 构建请求参数
	request := ollamaRequest{
		Model:    req.Model,
		Messages: messages,
		Stream:   req.Stream,
	}

	// 设置可选参数
	if req.Temperature > 0 {
		request.Temperature = req.Temperature
	}
	if req.TopP > 0 {
		request.TopP = req.TopP
	}
	if req.MaxTokens > 0 {
		request.MaxTokens = req.MaxTokens
	}
	if req.RepeatPenalty > 0 {
		request.RepeatPenalty = req.RepeatPenalty
	}

	body, err := json.Marshal(request)
	if err != nil {
		return &types.LlmChatResp{
			BaseResp:       common.HandleError(err),
			Content:        "",
			RemainingRatio: 1,
			Summarized:     false,
		}, nil
	}

	ctx, cancel := context.WithTimeout(l.ctx, time.Duration(timeoutSeconds)*time.Second)
	defer cancel()

	url := baseUrl + "/api/chat"

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return &types.LlmChatResp{
			BaseResp:       common.HandleError(err),
			Content:        "",
			RemainingRatio: 1,
			Summarized:     false,
		}, nil
	}
	common.ApplyOllamaForwardHeaders(httpReq)
	httpReq.Header.Set("Content-Type", "application/json")

	var httpResp *http.Response
	var retryErr error
	for i := 0; i <= utils.DefaultRetryConfig.MaxRetries; i++ {
		httpResp, retryErr = client.Do(httpReq)
		if retryErr == nil && httpResp.StatusCode == http.StatusOK {
			break
		}
		if retryErr == nil && !utils.IsRetryableStatus(httpResp.StatusCode) {
			break
		}
		if i < utils.DefaultRetryConfig.MaxRetries {
			delay := time.Duration(float64(utils.DefaultRetryConfig.InitialDelay) * (utils.DefaultRetryConfig.BackoffFactor * float64(i)))
			if delay > utils.DefaultRetryConfig.MaxDelay {
				delay = utils.DefaultRetryConfig.MaxDelay
			}
			time.Sleep(delay)
		}
	}

	if retryErr != nil {
		return &types.LlmChatResp{
			BaseResp:       common.HandleError(retryErr),
			Content:        "",
			RemainingRatio: 1,
			Summarized:     summarized,
		}, nil
	}
	defer httpResp.Body.Close()

	if httpResp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(httpResp.Body)
		return &types.LlmChatResp{
			BaseResp:       common.HandleError(fmt.Errorf("调用 Ollama 失败: %d %s", httpResp.StatusCode, string(raw))),
			Content:        "",
			RemainingRatio: 1,
			Summarized:     summarized,
		}, nil
	}

	var oResp ollamaResponse

	// 处理流式响应
	if req.Stream {
		// 这里应该返回流式响应，但由于当前接口设计，我们先收集所有内容
		// 实际生产环境中，应该使用Server-Sent Events或WebSocket
		reader := httpResp.Body
		decoder := json.NewDecoder(reader)
		var fullContent strings.Builder

		for {
			var chunk map[string]interface{}
			if err := decoder.Decode(&chunk); err != nil {
				if err == io.EOF {
					break
				}
				l.Errorf("decode stream chunk failed: %v", err)
				continue
			}

			if message, ok := chunk["message"].(map[string]interface{}); ok {
				if content, ok := message["content"].(string); ok {
					fullContent.WriteString(content)
				}
			}

			// 检查是否结束
			if done, ok := chunk["done"].(bool); ok && done {
				break
			}
		}

		oResp.Message.Content = fullContent.String()
	} else {
		// 处理非流式响应
		if err := json.NewDecoder(httpResp.Body).Decode(&oResp); err != nil {
			return &types.LlmChatResp{
				BaseResp:       common.HandleError(err),
				Content:        "",
				RemainingRatio: 1,
				Summarized:     summarized,
			}, nil
		}
	}
	oResp.Message.Content = sanitizePersonaResponse(oResp.Message.Content)

	// Async memory extraction
	if userIDForLog != "" {
		// Include the assistant's latest response in the history to be analyzed
		fullMessages := make([]ollamaMessage, len(messages)+1)
		copy(fullMessages, messages)
		fullMessages[len(messages)] = ollamaMessage{
			Role:    "assistant",
			Content: oResp.Message.Content,
		}

		go func(uid, model, baseUrl, sid, msgID string, timeout int, msgs []ollamaMessage) {
			bgCtx := context.Background()
			// Create a new detached logger/logic context if needed, but simple function call is enough
			l.extractAndSaveMemories(bgCtx, uid, model, baseUrl, timeout, sid, msgID, msgs)
		}(userIDForLog, req.Model, baseUrl, sessionID, sourceMsgID, timeoutSeconds, fullMessages)
	}

	usedTokens = 0
	if oResp.PromptEvalCount > 0 {
		usedTokens = oResp.PromptEvalCount
	} else {
		for _, m := range messages {
			usedTokens += estimateTokens(m.Content)
		}
	}

	remainingRatio := 1.0
	if usableTokens > 0 {
		remaining := usableTokens - usedTokens
		if remaining < 0 {
			remaining = 0
		}
		if remaining > usableTokens {
			remaining = usableTokens
		}
		remainingRatio = float64(remaining) / float64(usableTokens)
	}

	return &types.LlmChatResp{
		BaseResp:       common.HandleError(nil),
		Content:        oResp.Message.Content,
		RemainingRatio: remainingRatio,
		Summarized:     summarized,
	}, nil
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

func (l *ChatLogic) summarizeMessages(model, baseUrl string, timeoutSeconds int, client *http.Client, history []ollamaMessage) (string, error) {
	if len(history) == 0 {
		return "", nil
	}

	var sb strings.Builder
	for _, m := range history {
		role := m.Role
		if role == "" {
			role = "assistant"
		}
		sb.WriteString(role)
		sb.WriteString("：")
		sb.WriteString(m.Content)
		sb.WriteString("\n")
	}

	systemPrompt := strings.TrimSpace(l.svcCtx.Config.Ollama.MemorySummaryPrompt)
	if systemPrompt == "" {
		systemPrompt = "你是对话总结助手，需要用简短的中文总结下面的多轮对话，提炼出对后续对话有用的关键信息和记忆点，尽量控制在三到六条以内。"
	}

	reqBody, err := json.Marshal(ollamaRequest{
		Model: model,
		Messages: []ollamaMessage{
			{
				Role:    "system",
				Content: systemPrompt,
			},
			{
				Role:    "user",
				Content: sb.String(),
			},
		},
		Stream: false,
	})
	if err != nil {
		return "", err
	}

	ctx, cancel := context.WithTimeout(l.ctx, time.Duration(timeoutSeconds)*time.Second)
	defer cancel()

	url := strings.TrimRight(baseUrl, "/") + "/api/chat"

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(reqBody))
	if err != nil {
		return "", err
	}
	common.ApplyOllamaForwardHeaders(httpReq)
	httpReq.Header.Set("Content-Type", "application/json")

	var httpResp *http.Response
	var retryErr error
	for i := 0; i <= utils.DefaultRetryConfig.MaxRetries; i++ {
		httpResp, retryErr = client.Do(httpReq)
		if retryErr == nil && httpResp.StatusCode == http.StatusOK {
			break
		}
		if retryErr == nil && !utils.IsRetryableStatus(httpResp.StatusCode) {
			break
		}
		if i < utils.DefaultRetryConfig.MaxRetries {
			delay := time.Duration(float64(utils.DefaultRetryConfig.InitialDelay) * (utils.DefaultRetryConfig.BackoffFactor * float64(i)))
			if delay > utils.DefaultRetryConfig.MaxDelay {
				delay = utils.DefaultRetryConfig.MaxDelay
			}
			time.Sleep(delay)
		}
	}

	if retryErr != nil {
		return "", retryErr
	}
	defer httpResp.Body.Close()

	if httpResp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(httpResp.Body)
		return "", fmt.Errorf("summarize request failed: %d %s", httpResp.StatusCode, string(raw))
	}

	var oResp ollamaResponse
	if err := json.NewDecoder(httpResp.Body).Decode(&oResp); err != nil {
		return "", err
	}

	return oResp.Message.Content, nil
}

type memoryItem struct {
	Key        string  `json:"key"`
	Value      string  `json:"value"`
	MemoryType string  `json:"memory_type,omitempty"`
	Confidence float64 `json:"confidence,omitempty"`
	Source     string  `json:"source,omitempty"`
}

func (l *ChatLogic) extractAndSaveMemories(ctx context.Context, userID, model, baseUrl string, timeoutSeconds int, sessionID, sourceMsgID string, history []ollamaMessage) {
	// Only analyze if history is significant enough
	// 降低门槛，只要有对话就尝试（system + user + assistant >= 3）
	if len(history) < 2 {
		return
	}

	// 使用独立的 Logger，避免 context cancel 导致日志丢失或 trace 混乱
	logger := logx.WithContext(ctx)

	var sb strings.Builder
	for _, m := range history {
		role := m.Role
		if role == "system" {
			sb.WriteString("[系统信息]: ")
		} else {
			sb.WriteString(role)
			sb.WriteString(": ")
		}
		sb.WriteString(m.Content)
		sb.WriteString("\n")
	}

	// 针对中文小模型优化的 Prompt
	prompt := strings.TrimSpace(l.svcCtx.Config.Ollama.MemoryExtractPrompt)
	if prompt == "" {
		prompt = `请分析上述对话，提取关于“用户”（user）的新的、永久性的个人信息（如姓名、昵称、年龄、职业、爱好、位置、重要关系等）。
忽略：
1. [系统信息] 中已有的内容。
2. 临时的状态（如“我饿了”、“我在睡觉”）。
3. 无意义的闲聊。

请严格仅返回一个 JSON 列表，列表项为包含 "key" 和 "value" 的对象。
- key: 使用英文蛇形命名（如 user_name, hobby, profession）。
- value: 用户原本的语言（通常是中文）。
如果没有新信息，请返回空列表 []。

示例输出：
[{"key": "user_name", "value": "小萌"}, {"key": "hobby", "value": "画画"}]

请直接返回 JSON 字符串，不要包含 Markdown 格式（如 code block），不要包含其他解释文字。`
	}

	reqBody, err := json.Marshal(ollamaRequest{
		Model: model,
		Messages: []ollamaMessage{
			{
				Role:    "user",
				Content: sb.String() + "\n\n" + prompt,
			},
		},
		Stream: false,
	})
	if err != nil {
		logger.Errorf("marshal extract memory req failed: %v", err)
		return
	}

	reqCtx, cancel := context.WithTimeout(ctx, time.Duration(timeoutSeconds)*time.Second)
	defer cancel()

	url := strings.TrimRight(baseUrl, "/") + "/api/chat"
	httpReq, err := http.NewRequestWithContext(reqCtx, http.MethodPost, url, bytes.NewReader(reqBody))
	if err != nil {
		logger.Errorf("create extract memory req failed: %v", err)
		return
	}
	common.ApplyOllamaForwardHeaders(httpReq)
	httpReq.Header.Set("Content-Type", "application/json")

	client := utils.NewHTTPClient(timeoutSeconds)
	var httpResp *http.Response
	var retryErr error
	for i := 0; i <= utils.DefaultRetryConfig.MaxRetries; i++ {
		httpResp, retryErr = client.Do(httpReq)
		if retryErr == nil && httpResp.StatusCode == http.StatusOK {
			break
		}
		if retryErr == nil && !utils.IsRetryableStatus(httpResp.StatusCode) {
			break
		}
		if i < utils.DefaultRetryConfig.MaxRetries {
			delay := time.Duration(float64(utils.DefaultRetryConfig.InitialDelay) * (utils.DefaultRetryConfig.BackoffFactor * float64(i)))
			if delay > utils.DefaultRetryConfig.MaxDelay {
				delay = utils.DefaultRetryConfig.MaxDelay
			}
			time.Sleep(delay)
		}
	}

	if retryErr != nil {
		logger.Errorf("extract memory http request failed: %v", retryErr)
		return
	}
	defer httpResp.Body.Close()

	if httpResp.StatusCode != http.StatusOK {
		logger.Errorf("extract memory api failed: %d", httpResp.StatusCode)
		return
	}

	var oResp ollamaResponse
	if err := json.NewDecoder(httpResp.Body).Decode(&oResp); err != nil {
		logger.Errorf("decode extract memory resp failed: %v", err)
		return
	}

	content := strings.TrimSpace(oResp.Message.Content)
	logger.Infof("memory extraction response received: chars=%d", len([]rune(content)))

	// Clean up potential markdown code blocks
	content = strings.TrimPrefix(content, "```json")
	content = strings.TrimPrefix(content, "```")
	content = strings.TrimSuffix(content, "```")
	content = strings.TrimSpace(content)

	if content == "[]" || content == "" {
		return
	}

	var items []memoryItem
	if err := json.Unmarshal([]byte(content), &items); err != nil {
		// 仅记录长度，避免把潜在隐私内容写入日志。
		logger.Errorf("unmarshal memory items failed: %v, chars=%d", err, len([]rune(content)))
		return
	}

	if len(items) > 0 {
		logger.Infof("extracted %d new memories for user %s", len(items), userID)
		for _, item := range items {
			if item.Key == "" || item.Value == "" {
				continue
			}
			_, err := l.svcCtx.SuperRpcClient.UpsertUserMemory(ctx, &super.UpsertUserMemoryReq{
				UserId:      userID,
				Key:         item.Key,
				Value:       item.Value,
				MemoryType:  item.MemoryType,
				Confidence:  item.Confidence,
				Source:      "llm_extract",
				SourceMsgId: sourceMsgID,
				SessionId:   sessionID,
			})
			if err != nil {
				logger.Errorf("upsert memory %s failed: %v", item.Key, err)
			}
		}
		// 发生更新后失效缓存，避免后续会话继续命中过时记忆。
		invalidateCachedUserMemories(userID)
	}
}
