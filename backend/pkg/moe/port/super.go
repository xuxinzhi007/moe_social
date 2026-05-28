package port

import (
	"context"

	"backend/rpc/pb/moe"
)

// SuperPort Moe 模块所需的 RPC 能力子集（API 走 gRPC 客户端，RPC 进程走本地 logic）。
type SuperPort interface {
	GetUserMemories(ctx context.Context, in *moe.GetUserMemoriesReq) (*moe.GetUserMemoriesResp, error)
	UpsertUserMemory(ctx context.Context, in *moe.UpsertUserMemoryReq) (*moe.UpsertUserMemoryResp, error)
	DeleteUserMemory(ctx context.Context, in *moe.DeleteUserMemoryReq) (*moe.DeleteUserMemoryResp, error)
	CreatePost(ctx context.Context, in *moe.CreatePostReq) (*moe.CreatePostResp, error)
	UpdatePost(ctx context.Context, in *moe.UpdatePostReq) (*moe.UpdatePostResp, error)
	GetPost(ctx context.Context, in *moe.GetPostReq) (*moe.GetPostResp, error)
}

// GRPCAdapter 将 SuperClient 适配为 SuperPort。
type GRPCAdapter struct {
	Client moe.SuperClient
}

func (a GRPCAdapter) GetUserMemories(ctx context.Context, in *moe.GetUserMemoriesReq) (*moe.GetUserMemoriesResp, error) {
	return a.Client.GetUserMemories(ctx, in)
}

func (a GRPCAdapter) UpsertUserMemory(ctx context.Context, in *moe.UpsertUserMemoryReq) (*moe.UpsertUserMemoryResp, error) {
	return a.Client.UpsertUserMemory(ctx, in)
}

func (a GRPCAdapter) DeleteUserMemory(ctx context.Context, in *moe.DeleteUserMemoryReq) (*moe.DeleteUserMemoryResp, error) {
	return a.Client.DeleteUserMemory(ctx, in)
}

func (a GRPCAdapter) CreatePost(ctx context.Context, in *moe.CreatePostReq) (*moe.CreatePostResp, error) {
	return a.Client.CreatePost(ctx, in)
}

func (a GRPCAdapter) UpdatePost(ctx context.Context, in *moe.UpdatePostReq) (*moe.UpdatePostResp, error) {
	return a.Client.UpdatePost(ctx, in)
}

func (a GRPCAdapter) GetPost(ctx context.Context, in *moe.GetPostReq) (*moe.GetPostResp, error) {
	return a.Client.GetPost(ctx, in)
}
