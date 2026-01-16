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

	systemContent := "你是一个社交应用中的 AI 助手，需要结合用户与助手的历史对话内容进行连续、多轮的中文交流。当用户提到“刚才”“之前”“上面说的”等表达时，需要基于完整的聊天记录理解含义并回答。"
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

	body, err := json.Marshal(ollamaRequest{
		Model:    req.Model,
		Messages: messages,
		Stream:   false,
	})
	if err != nil {
		return &types.LlmChatResp{
			BaseResp: common.HandleError(err),
			Content:  "",
		}, nil
	}

	timeoutSeconds := l.svcCtx.Config.Ollama.TimeoutSeconds
	if timeoutSeconds <= 0 {
		timeoutSeconds = 60
	}

	baseUrl := strings.TrimRight(l.svcCtx.Config.Ollama.BaseUrl, "/")
	if baseUrl == "" {
		baseUrl = "http://127.0.0.1:11434"
	}

	ctx, cancel := context.WithTimeout(l.ctx, time.Duration(timeoutSeconds)*time.Second)
	defer cancel()

	client := &http.Client{
		Timeout: time.Duration(timeoutSeconds) * time.Second,
	}

	url := baseUrl + "/api/chat"

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return &types.LlmChatResp{
			BaseResp: common.HandleError(err),
			Content:  "",
		}, nil
	}
	httpReq.Header.Set("Content-Type", "application/json")

	httpResp, err := client.Do(httpReq)
	if err != nil {
		return &types.LlmChatResp{
			BaseResp: common.HandleError(err),
			Content:  "",
		}, nil
	}
	defer httpResp.Body.Close()

	if httpResp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(httpResp.Body)
		return &types.LlmChatResp{
			BaseResp: common.HandleError(fmt.Errorf("调用 Ollama 失败: %d %s", httpResp.StatusCode, string(raw))),
			Content:  "",
		}, nil
	}

	var oResp ollamaResponse
	if err := json.NewDecoder(httpResp.Body).Decode(&oResp); err != nil {
		return &types.LlmChatResp{
			BaseResp: common.HandleError(err),
			Content:  "",
		}, nil
	}

	return &types.LlmChatResp{
		BaseResp: common.HandleError(nil),
		Content:  oResp.Message.Content,
	}, nil
}
