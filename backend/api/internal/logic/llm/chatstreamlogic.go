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

	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

// ChatStreamLogic 负责向 Ollama 发起 stream:true 的请求，返回一个逐行 JSON 的响应流。
// Handler 负责把该流转发为 SSE（text/event-stream）给前端。
type ChatStreamLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewChatStreamLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ChatStreamLogic {
	return &ChatStreamLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ChatStreamLogic) Stream(req *types.LlmChatReq) (io.ReadCloser, error) {
	type ollamaMessage struct {
		Role    string `json:"role"`
		Content string `json:"content"`
	}

	type ollamaRequest struct {
		Model    string          `json:"model"`
		Messages []ollamaMessage `json:"messages"`
		Stream   bool            `json:"stream"`
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
		Stream:   true,
	})
	if err != nil {
		return nil, err
	}

	timeoutSeconds := l.svcCtx.Config.Ollama.TimeoutSeconds
	if timeoutSeconds <= 0 {
		timeoutSeconds = 300
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
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	httpResp, err := client.Do(httpReq)
	if err != nil {
		return nil, err
	}

	if httpResp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(httpResp.Body)
		_ = httpResp.Body.Close()
		return nil, fmt.Errorf("调用 Ollama 失败: %d %s", httpResp.StatusCode, string(raw))
	}

	// Caller 负责 Close
	return httpResp.Body, nil
}
