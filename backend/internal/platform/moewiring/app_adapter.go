package moewiring

import (
	"context"
	"errors"

	llmv1 "backend/api/llm/v1"
	postv1 "backend/api/post/v1"
	llmapp "backend/internal/service/llm"
	postapp "backend/internal/service/post"
	"backend/pkg/moe/port"
)

var errAppPortUnavailable = errors.New("super port: in-process app unavailable")

// appAdapter 进程内 MoeToolPort（P5：Super gRPC 退役后 Moe 试跑/工具链直连 App）。
type appAdapter struct {
	post *postapp.AppService
	llm  *llmapp.AppService
}

// NewAppAdapter 构造进程内 MoeToolPort；post/llm 可为 nil（对应方法返回不可用错误）。
func NewAppAdapter(post *postapp.AppService, llm *llmapp.AppService) port.MoeToolPort {
	return appAdapter{post: post, llm: llm}
}

func (a appAdapter) GetUserMemories(ctx context.Context, in *llmv1.GetUserMemoriesReq) (*llmv1.GetUserMemoriesResp, error) {
	if a.llm == nil {
		return nil, errAppPortUnavailable
	}
	return a.llm.GetUserMemories(ctx, in)
}

func (a appAdapter) UpsertUserMemory(ctx context.Context, in *llmv1.UpsertUserMemoryReq) (*llmv1.UpsertUserMemoryResp, error) {
	if a.llm == nil {
		return nil, errAppPortUnavailable
	}
	return a.llm.UpsertUserMemory(ctx, in)
}

func (a appAdapter) DeleteUserMemory(ctx context.Context, in *llmv1.DeleteUserMemoryReq) (*llmv1.DeleteUserMemoryResp, error) {
	if a.llm == nil {
		return nil, errAppPortUnavailable
	}
	return a.llm.DeleteUserMemory(ctx, in)
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
