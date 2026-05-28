package moewiring

import (
	"context"
	"errors"

	llmapp "backend/internal/service/llm"
	postapp "backend/internal/service/post"
	"backend/pkg/moe/port"
	"backend/rpc/pb/moe"
)

var errAppPortUnavailable = errors.New("super port: in-process app unavailable")

// appAdapter 进程内 SuperPort（P5：Super gRPC 退役后 Moe 试跑/工具链直连 App）。
type appAdapter struct {
	post *postapp.AppService
	llm  *llmapp.AppService
}

// NewAppAdapter 构造进程内 SuperPort；post/llm 可为 nil（对应方法返回不可用错误）。
func NewAppAdapter(post *postapp.AppService, llm *llmapp.AppService) port.SuperPort {
	return appAdapter{post: post, llm: llm}
}

func (a appAdapter) GetUserMemories(ctx context.Context, in *moe.GetUserMemoriesReq) (*moe.GetUserMemoriesResp, error) {
	if a.llm == nil {
		return nil, errAppPortUnavailable
	}
	return a.llm.GetUserMemories(ctx, in)
}

func (a appAdapter) UpsertUserMemory(ctx context.Context, in *moe.UpsertUserMemoryReq) (*moe.UpsertUserMemoryResp, error) {
	if a.llm == nil {
		return nil, errAppPortUnavailable
	}
	return a.llm.UpsertUserMemory(ctx, in)
}

func (a appAdapter) DeleteUserMemory(ctx context.Context, in *moe.DeleteUserMemoryReq) (*moe.DeleteUserMemoryResp, error) {
	if a.llm == nil {
		return nil, errAppPortUnavailable
	}
	return a.llm.DeleteUserMemory(ctx, in)
}

func (a appAdapter) CreatePost(ctx context.Context, in *moe.CreatePostReq) (*moe.CreatePostResp, error) {
	if a.post == nil {
		return nil, errAppPortUnavailable
	}
	return a.post.CreatePost(ctx, in)
}

func (a appAdapter) UpdatePost(ctx context.Context, in *moe.UpdatePostReq) (*moe.UpdatePostResp, error) {
	if a.post == nil {
		return nil, errAppPortUnavailable
	}
	return a.post.UpdatePost(ctx, in)
}

func (a appAdapter) GetPost(ctx context.Context, in *moe.GetPostReq) (*moe.GetPostResp, error) {
	if a.post == nil {
		return nil, errAppPortUnavailable
	}
	return a.post.GetPost(ctx, in)
}
