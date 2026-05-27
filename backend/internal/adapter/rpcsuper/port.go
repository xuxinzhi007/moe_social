package rpcsuper

import (
	"context"

	"backend/pkg/moe/port"
	"backend/rpc/pb/super"
)

type superPort struct {
	bridge Bridge
}

// NewSuperPort 构造进程内 Super gRPC 委托端口。
func NewSuperPort(_ context.Context, bridge Bridge) port.SuperPort {
	if bridge == nil {
		return nil
	}
	return superPort{bridge: bridge}
}

func (p superPort) GetUserMemories(ctx context.Context, in *super.GetUserMemoriesReq) (*super.GetUserMemoriesResp, error) {
	return p.bridge.GetUserMemories(ctx, in)
}

func (p superPort) UpsertUserMemory(ctx context.Context, in *super.UpsertUserMemoryReq) (*super.UpsertUserMemoryResp, error) {
	return p.bridge.UpsertUserMemory(ctx, in)
}

func (p superPort) DeleteUserMemory(ctx context.Context, in *super.DeleteUserMemoryReq) (*super.DeleteUserMemoryResp, error) {
	return p.bridge.DeleteUserMemory(ctx, in)
}

func (p superPort) CreatePost(ctx context.Context, in *super.CreatePostReq) (*super.CreatePostResp, error) {
	return p.bridge.CreatePost(ctx, in)
}

func (p superPort) UpdatePost(ctx context.Context, in *super.UpdatePostReq) (*super.UpdatePostResp, error) {
	return p.bridge.UpdatePost(ctx, in)
}

func (p superPort) GetPost(ctx context.Context, in *super.GetPostReq) (*super.GetPostResp, error) {
	return p.bridge.GetPost(ctx, in)
}
