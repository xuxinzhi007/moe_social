// Package contentapp 内容生成应用服务。
package contentapp

import (
	"context"
	"errors"

	contentbiz "backend/internal/biz/content"
)

// AppService 内容生成应用层。
type AppService struct{}

// New 构造 AppService。
func New() *AppService {
	return &AppService{}
}

// GenerateContent 生成内容。
func (s *AppService) GenerateContent(ctx context.Context, in contentbiz.GenerateInput) (contentbiz.GenerateResult, error) {
	if s == nil {
		return contentbiz.GenerateResult{}, errors.New("content app unavailable")
	}
	return contentbiz.GenerateContent(ctx, in)
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
