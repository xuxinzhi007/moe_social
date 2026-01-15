package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

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

	messages := make([]ollamaMessage, 0, len(req.Messages))
	for _, m := range req.Messages {
		messages = append(messages, ollamaMessage{
			Role:    m.Role,
			Content: m.Content,
		})
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

	client := &http.Client{
		Timeout: 60 * time.Second,
	}

	url := "http://127.0.0.1:11434/api/chat"

	httpReq, err := http.NewRequestWithContext(l.ctx, http.MethodPost, url, bytes.NewReader(body))
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
