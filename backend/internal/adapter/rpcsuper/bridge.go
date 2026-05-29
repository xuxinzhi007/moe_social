package rpcsuper

import (
	"context"

	"backend/rpc/pb/moe"
)

// Bridge 由 RPC logic 实现，供进程内 MoeToolPort 委托（避免 adapter ↔ logic 循环 import）。
type Bridge interface {
	GetUserMemories(ctx context.Context, in *moe.GetUserMemoriesReq) (*moe.GetUserMemoriesResp, error)
	UpsertUserMemory(ctx context.Context, in *moe.UpsertUserMemoryReq) (*moe.UpsertUserMemoryResp, error)
	DeleteUserMemory(ctx context.Context, in *moe.DeleteUserMemoryReq) (*moe.DeleteUserMemoryResp, error)
	CreatePost(ctx context.Context, in *moe.CreatePostReq) (*moe.CreatePostResp, error)
	UpdatePost(ctx context.Context, in *moe.UpdatePostReq) (*moe.UpdatePostResp, error)
	GetPost(ctx context.Context, in *moe.GetPostReq) (*moe.GetPostResp, error)
}
