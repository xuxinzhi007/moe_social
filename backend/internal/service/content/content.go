// Package contentapp 内容生成应用服务。
package contentapp

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	contentbiz "backend/internal/biz/content"
	llmbiz "backend/internal/biz/llm"

	"github.com/google/uuid"
)

// ChatRunner runs backend-owned LLM chat requests for content generation.
type ChatRunner interface {
	Chat(context.Context, llmbiz.PlatformChatInput) (llmbiz.PlatformChatOutcome, error)
}

// AppService 内容生成应用层。
type AppService struct {
	llm ChatRunner
}

// New 构造 AppService。
func New(runners ...ChatRunner) *AppService {
	var runner ChatRunner
	if len(runners) > 0 {
		runner = runners[0]
	}
	return &AppService{llm: runner}
}

// GenerateContent 生成内容。
func (s *AppService) GenerateContent(ctx context.Context, in contentbiz.GenerateInput) (contentbiz.GenerateResult, error) {
	if s == nil {
		return contentbiz.GenerateResult{}, errors.New("content app unavailable")
	}
	if s.llm == nil {
		return contentbiz.GenerateResult{}, errors.New("content generation llm unavailable")
	}
	normalized, err := contentbiz.NormalizeGenerateInput(in)
	if err != nil {
		return contentbiz.GenerateResult{}, err
	}
	systemPrompt, _ := contentbiz.ContentSystemPrompt(normalized.Type)
	outcome, err := s.llm.Chat(ctx, llmbiz.PlatformChatInput{
		AgentID:            optionString(normalized.Options, "agent_id"),
		ServerSystemPrompt: systemPrompt,
		Messages: []llmbiz.PlatformChatMessage{
			{Role: "user", Content: normalized.Prompt},
		},
	})
	if err != nil {
		return contentbiz.GenerateResult{}, fmt.Errorf("generate content via llm: %w", err)
	}
	if !outcome.Success {
		return contentbiz.GenerateResult{}, errors.New(outcome.Message)
	}
	content := strings.TrimSpace(outcome.Content)
	if content == "" {
		return contentbiz.GenerateResult{}, errors.New("content generation returned empty content")
	}
	return contentbiz.GenerateResult{
		ID:        uuid.NewString(),
		Type:      normalized.Type,
		Content:   content,
		CreatedAt: time.Now().Format(time.RFC3339),
	}, nil
}

// ListContent 分页查询用户内容列表。
func (s *AppService) ListContent(_ context.Context, in contentbiz.ListInput) contentbiz.ListResult {
	if s == nil {
		return contentbiz.ListResult{}
	}
	return contentbiz.ListContent(in)
}

// ErrUnsupportedContentType 不支持的内容类型。
var ErrUnsupportedContentType = contentbiz.ErrUnsupportedContentType

func optionString(options map[string]interface{}, key string) string {
	if options == nil {
		return ""
	}
	value, ok := options[key]
	if !ok || value == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(value))
}
