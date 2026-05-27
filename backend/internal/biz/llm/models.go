package llmbiz

import (
	"context"

	"backend/pkg/llminference"
)

// ListModelNames 从推理服务拉取模型列表。
func ListModelNames(ctx context.Context, cfg llminference.Config) ([]string, error) {
	return llminference.ListModelNames(ctx, cfg)
}
