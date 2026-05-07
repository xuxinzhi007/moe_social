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
)

var ctxSafeRatio = 0.7
var memoryTokenPattern = regexp.MustCompile(`[\p{Han}]{2,}|[a-zA-Z0-9_]{2,}`)

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
}

func estimateTokens(s string) int {
	return len([]rune(s))
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
	ranked := make([]rankedMemory, 0, len(memories))
	seen := make(map[string]struct{}, len(memories))

	for i, m := range memories {
		key := strings.TrimSpace(m.Key)
		value := strings.TrimSpace(m.Value)
		if key == "" || value == "" {
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
		for _, token := range tokens {
			if strings.Contains(joined, token) {
				score += 3
			}
		}

		ranked = append(ranked, rankedMemory{
			line:  line,
			score: score,
			index: i,
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

	lines := make([]string, 0, min(maxInjectedMemoryItems, len(ranked)))
	totalRunes := 0
	for _, item := range ranked {
		itemRunes := len([]rune(item.line))
		if len(lines) >= maxInjectedMemoryItems {
			break
		}
		if totalRunes+itemRunes > maxInjectedMemoryRunes && len(lines) > 0 {
			break
		}
		lines = append(lines, item.line)
		totalRunes += itemRunes
	}

	// 没有命中时至少兜底注入 2 条最近记忆，避免“完全失忆”。
	if len(lines) == 0 {
		limit := min(2, len(ranked))
		for i := 0; i < limit; i++ {
			lines = append(lines, ranked[i].line)
		}
	}
	return lines
}

func (l *ChatLogic) Chat(req *types.LlmChatReq) (resp *types.LlmChatResp, err error) {
	var memoryLines []string
	var userIDForLog string
	if v := l.ctx.Value("user_id"); v != nil {
		if userID, ok := v.(string); ok && userID != "" {
			userIDForLog = userID
			rpcResp, err := l.svcCtx.SuperRpcClient.GetUserMemories(l.ctx, &super.GetUserMemoriesReq{
				UserId: userID,
			})
			if err != nil {
				l.Errorf("GetUserMemories failed: %v", err)
			} else {
				memoryLines = selectRelevantMemoryLines(rpcResp.Memories, req.Messages)
				l.Infof("loaded memories for user_id=%s total=%d selected=%d", userID, len(rpcResp.Memories), len(memoryLines))
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
		systemContent = clientSystemPrompt
	} else {
		systemContent = "你是一个社交应用中的中文 AI 助手。你的目标是真正理解用户的需求，并给出自然、具体、可执行的中文回答。\n\n你需要：\n1. 主动结合当前消息和完整历史对话来理解用户真正想做什么，而不是只按字面意思机械回复。\n2. 当用户表达不清晰或有多种可能理解时，先用一两句简短话语确认或澄清需求，再继续回答。\n3. 当用户说“帮我总结一下聊天”“总结一下刚才的内容”等时，直接基于你看到的全部对话记录给出清晰的要点式总结，不要让用户去复制聊天记录。\n4. 当用户询问如何实现某个功能或写代码时，请给出具体步骤和示例，而不是泛泛而谈。\n\n当用户提到“刚才”“之前”“上面说的”等表达时，需要基于完整的聊天记录理解含义并回答。"
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

	baseUrl := strings.TrimRight(l.svcCtx.Config.Ollama.BaseUrl, "/")
	if baseUrl == "" {
		baseUrl = "http://127.0.0.1:11434"
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

				go func(uid, model, baseUrl string, timeout int, msgs []ollamaMessage) {
					bgCtx := context.Background()
					l.extractAndSaveMemories(bgCtx, uid, model, baseUrl, timeout, msgs)
				}(userIDForLog, memoryModel, baseUrl, timeoutSeconds, fullMessages)
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

	// Async memory extraction
	if userIDForLog != "" {
		// Include the assistant's latest response in the history to be analyzed
		fullMessages := make([]ollamaMessage, len(messages)+1)
		copy(fullMessages, messages)
		fullMessages[len(messages)] = ollamaMessage{
			Role:    "assistant",
			Content: oResp.Message.Content,
		}

		go func(uid, model, baseUrl string, timeout int, msgs []ollamaMessage) {
			bgCtx := context.Background()
			// Create a new detached logger/logic context if needed, but simple function call is enough
			l.extractAndSaveMemories(bgCtx, uid, model, baseUrl, timeout, msgs)
		}(userIDForLog, req.Model, baseUrl, timeoutSeconds, fullMessages)
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
	Key   string `json:"key"`
	Value string `json:"value"`
}

func (l *ChatLogic) extractAndSaveMemories(ctx context.Context, userID, model, baseUrl string, timeoutSeconds int, history []ollamaMessage) {
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
		// 尝试容错：如果不是标准 JSON，尝试提取类似 JSON 的部分
		// 这里简单处理，如果解析失败记录日志
		logger.Errorf("unmarshal memory items failed: %v, content: %s", err, content)
		return
	}

	if len(items) > 0 {
		logger.Infof("extracted %d new memories for user %s", len(items), userID)
		for _, item := range items {
			if item.Key == "" || item.Value == "" {
				continue
			}
			_, err := l.svcCtx.SuperRpcClient.UpsertUserMemory(ctx, &super.UpsertUserMemoryReq{
				UserId: userID,
				Key:    item.Key,
				Value:  item.Value,
			})
			if err != nil {
				logger.Errorf("upsert memory %s failed: %v", item.Key, err)
			}
		}
	}
}
