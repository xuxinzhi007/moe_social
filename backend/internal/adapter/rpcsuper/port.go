package rpcsuper

import (
	"context"

	"backend/pkg/moe/port"
	"backend/rpc/pb/moe"
)

type moeToolPort struct {
	bridge Bridge
}

// NewMoeToolPort 构造进程内 Super gRPC 委托端口。
func NewMoeToolPort(_ context.Context, bridge Bridge) port.MoeToolPort {
	if bridge == nil {
		return nil
	}
	return moeToolPort{bridge: bridge}
}

func (p moeToolPort) GetUserMemories(ctx context.Context, in *moe.GetUserMemoriesReq) (*moe.GetUserMemoriesResp, error) {
	return p.bridge.GetUserMemories(ctx, in)
}

func (p moeToolPort) UpsertUserMemory(ctx context.Context, in *moe.UpsertUserMemoryReq) (*moe.UpsertUserMemoryResp, error) {
	return p.bridge.UpsertUserMemory(ctx, in)
}

func (p moeToolPort) DeleteUserMemory(ctx context.Context, in *moe.DeleteUserMemoryReq) (*moe.DeleteUserMemoryResp, error) {
	return p.bridge.DeleteUserMemory(ctx, in)
}

func (p moeToolPort) CreatePost(ctx context.Context, in *moe.CreatePostReq) (*moe.CreatePostResp, error) {
	return p.bridge.CreatePost(ctx, in)
}

func (p moeToolPort) UpdatePost(ctx context.Context, in *moe.UpdatePostReq) (*moe.UpdatePostResp, error) {
	return p.bridge.UpdatePost(ctx, in)
}

func (p moeToolPort) GetPost(ctx context.Context, in *moe.GetPostReq) (*moe.GetPostResp, error) {
	return p.bridge.GetPost(ctx, in)
}
