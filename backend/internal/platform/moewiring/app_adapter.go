package moewiring

import (
	"context"
	"errors"

	postv1 "backend/api/post/v1"
	llmapp "backend/internal/service/llm"
	postapp "backend/internal/service/post"
	"backend/pkg/moe/port"
)

var errAppPortUnavailable = errors.New("super port: in-process app unavailable")

// appAdapter 进程内 MoeToolPort（P5：Super gRPC 退役后 Moe 试跑/工具链直连 App）。
type appAdapter struct {
	post *postapp.AppService
}

// NewAppAdapter 构造进程内 MoeToolPort；post/llm 可为 nil（对应方法返回不可用错误）。
func NewAppAdapter(post *postapp.AppService, _ *llmapp.AppService) port.MoeToolPort {
	return appAdapter{post: post}
}

func (a appAdapter) CreatePost(ctx context.Context, in *postv1.CreatePostRequest) (*postv1.CreatePostReply, error) {
	if a.post == nil {
		return nil, errAppPortUnavailable
	}
	return a.post.CreatePost(ctx, in)
}

func (a appAdapter) UpdatePost(ctx context.Context, in *postv1.UpdatePostRequest) (*postv1.UpdatePostReply, error) {
	if a.post == nil {
		return nil, errAppPortUnavailable
	}
	return a.post.UpdatePost(ctx, in)
}

func (a appAdapter) GetPost(ctx context.Context, in *postv1.GetPostRequest) (*postv1.GetPostReply, error) {
	if a.post == nil {
		return nil, errAppPortUnavailable
	}
	return a.post.GetPost(ctx, in)
}
