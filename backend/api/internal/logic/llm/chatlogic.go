package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

const (
	maxCtxTokens       = 4096
	maxHistoryMessages = 40
	keepRecentMessages = 16
)

var ctxSafeRatio = 0.7

type ollamaMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ollamaRequest struct {
	Model    string          `json:"model"`
	Messages []ollamaMessage `json:"messages"`
	Stream   bool            `json:"stream"`
}

type ollamaResponse struct {
	Message struct {
		Role    string `json:"role"`
		Content string `json:"content"`
	} `json:"message"`
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
				for _, m := range rpcResp.Memories {
					if m.Key != "" && m.Value != "" {
						memoryLines = append(memoryLines, fmt.Sprintf("%s: %s", m.Key, m.Value))
					}
				}
				l.Infof("loaded %d memories for user_id=%s", len(rpcResp.Memories), userID)
			}
		}
	}

	systemContent := "你是一个社交应用中的中文 AI 助手。你的目标是真正理解用户的需求，并给出自然、具体、可执行的中文回答。\n\n你需要：\n1. 主动结合当前消息和完整历史对话来理解用户真正想做什么，而不是只按字面意思机械回复。\n2. 当用户表达不清晰或有多种可能理解时，先用一两句简短话语确认或澄清需求，再继续回答。\n3. 当用户说“帮我总结一下聊天”“总结一下刚才的内容”等时，直接基于你看到的全部对话记录给出清晰的要点式总结，不要让用户去复制聊天记录。\n4. 当用户询问如何实现某个功能或写代码时，请给出具体步骤和示例，而不是泛泛而谈。\n\n当用户提到“刚才”“之前”“上面说的”等表达时，需要基于完整的聊天记录理解含义并回答。"
	if len(memoryLines) > 0 {
		systemContent = systemContent + "\n\n用户的长期背景与偏好信息如下，请在回答时适当参考：\n- " + strings.Join(memoryLines, "\n- ")
	}

	messages := make([]ollamaMessage, 0, len(req.Messages)+1)

	messages = append(messages, ollamaMessage{
		Role:    "system",
		Content: systemContent,
	})

	for _, m := range req.Messages {
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

	client := &http.Client{
		Timeout: time.Duration(timeoutSeconds) * time.Second,
	}

	usedTokens := 0
	for _, m := range messages {
		usedTokens += estimateTokens(m.Content)
	}

	usableTokens := int(float64(maxCtxTokens) * ctxSafeRatio)
	if usableTokens <= 0 {
		usableTokens = maxCtxTokens
	}

	summarized := false

	if len(req.Messages) > maxHistoryMessages && len(messages) > 1+keepRecentMessages {
		oldEnd := len(messages) - keepRecentMessages
		if oldEnd <= 1 {
			oldEnd = 1
		}
		oldMessages := make([]ollamaMessage, oldEnd-1)
		copy(oldMessages, messages[1:oldEnd])

		summary, sumErr := l.summarizeMessages(req.Model, baseUrl, timeoutSeconds, client, oldMessages)
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

	body, err := json.Marshal(ollamaRequest{
		Model:    req.Model,
		Messages: messages,
		Stream:   false,
	})
	if err != nil {
		return &types.LlmChatResp{
			BaseResp:        common.HandleError(err),
			Content:         "",
			RemainingRatio:  1,
			Summarized:      false,
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

	httpResp, err := client.Do(httpReq)
	if err != nil {
		return &types.LlmChatResp{
			BaseResp:       common.HandleError(err),
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
	if err := json.NewDecoder(httpResp.Body).Decode(&oResp); err != nil {
		return &types.LlmChatResp{
			BaseResp:       common.HandleError(err),
			Content:        "",
			RemainingRatio: 1,
			Summarized:     summarized,
		}, nil
	}

	usedTokens = 0
	for _, m := range messages {
		usedTokens += estimateTokens(m.Content)
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

	systemPrompt := "你是对话总结助手，需要用简短的中文总结下面的多轮对话，提炼出对后续对话有用的关键信息和记忆点，尽量控制在三到六条以内。"

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

	httpResp, err := client.Do(httpReq)
	if err != nil {
		return "", err
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
