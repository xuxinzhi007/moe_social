package rpcsuper

import (
	"context"

	"backend/rpc/pb/super"
)

// Bridge 由 RPC logic 实现，供进程内 SuperPort 委托（避免 adapter ↔ logic 循环 import）。
type Bridge interface {
	GetUserMemories(ctx context.Context, in *super.GetUserMemoriesReq) (*super.GetUserMemoriesResp, error)
	UpsertUserMemory(ctx context.Context, in *super.UpsertUserMemoryReq) (*super.UpsertUserMemoryResp, error)
	DeleteUserMemory(ctx context.Context, in *super.DeleteUserMemoryReq) (*super.DeleteUserMemoryResp, error)
	CreatePost(ctx context.Context, in *super.CreatePostReq) (*super.CreatePostResp, error)
	UpdatePost(ctx context.Context, in *super.UpdatePostReq) (*super.UpdatePostResp, error)
	GetPost(ctx context.Context, in *super.GetPostReq) (*super.GetPostResp, error)
}
