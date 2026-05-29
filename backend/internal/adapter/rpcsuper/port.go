package rpcsuper

import (
	"context"

	llmv1 "backend/api/llm/v1"
	postv1 "backend/api/post/v1"
	"backend/pkg/moe/port"
)

type moeToolPort struct {
	bridge Bridge
}

// NewMoeToolPort 构造进程内 Moe 工具端口。
func NewMoeToolPort(_ context.Context, bridge Bridge) port.MoeToolPort {
	if bridge == nil {
		return nil
	}
	return moeToolPort{bridge: bridge}
}

func (p moeToolPort) GetUserMemories(ctx context.Context, in *llmv1.GetUserMemoriesReq) (*llmv1.GetUserMemoriesResp, error) {
	return p.bridge.GetUserMemories(ctx, in)
}

func (p moeToolPort) UpsertUserMemory(ctx context.Context, in *llmv1.UpsertUserMemoryReq) (*llmv1.UpsertUserMemoryResp, error) {
	return p.bridge.UpsertUserMemory(ctx, in)
}

func (p moeToolPort) DeleteUserMemory(ctx context.Context, in *llmv1.DeleteUserMemoryReq) (*llmv1.DeleteUserMemoryResp, error) {
	return p.bridge.DeleteUserMemory(ctx, in)
}

func (p moeToolPort) CreatePost(ctx context.Context, in *postv1.CreatePostRequest) (*postv1.CreatePostReply, error) {
	return p.bridge.CreatePost(ctx, in)
}

func (p moeToolPort) UpdatePost(ctx context.Context, in *postv1.UpdatePostRequest) (*postv1.UpdatePostReply, error) {
	return p.bridge.UpdatePost(ctx, in)
}

func (p moeToolPort) GetPost(ctx context.Context, in *postv1.GetPostRequest) (*postv1.GetPostReply, error) {
	return p.bridge.GetPost(ctx, in)
}
