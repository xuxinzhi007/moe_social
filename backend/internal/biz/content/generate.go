package contentbiz

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// ErrUnsupportedContentType 不支持的内容类型。
var ErrUnsupportedContentType = errors.New("unsupported content type")

// GenerateInput 内容生成请求。
type GenerateInput struct {
	UserID  string
	Type    string
	Prompt  string
	Options map[string]interface{}
}

// GenerateResult 内容生成结果。
type GenerateResult struct {
	ID        string
	Type      string
	URL       string
	Content   string
	CreatedAt string
}

// GenerateContent 按类型生成内容（当前为占位实现）。
func GenerateContent(_ context.Context, in GenerateInput) (GenerateResult, error) {
	contentID := uuid.New().String()
	createdAt := time.Now().Format(time.RFC3339)

	result := GenerateResult{
		ID:        contentID,
		Type:      in.Type,
		CreatedAt: createdAt,
	}

	switch in.Type {
	case "text":
		result.Content = fmt.Sprintf("生成的文本内容: %s", in.Prompt)
	case "image":
		result.URL = fmt.Sprintf("https://example.com/images/%s.jpg", contentID)
	case "video":
		result.URL = fmt.Sprintf("https://example.com/videos/%s.mp4", contentID)
	default:
		return GenerateResult{}, ErrUnsupportedContentType
	}
	return result, nil
}
