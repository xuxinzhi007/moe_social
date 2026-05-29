package port

import (
	"context"

	llmv1 "backend/api/llm/v1"
	postv1 "backend/api/post/v1"
)

// MoeToolPort Moe 模块所需的 App 能力子集（进程内直连 service）。
type MoeToolPort interface {
	GetUserMemories(ctx context.Context, in *llmv1.GetUserMemoriesReq) (*llmv1.GetUserMemoriesResp, error)
	UpsertUserMemory(ctx context.Context, in *llmv1.UpsertUserMemoryReq) (*llmv1.UpsertUserMemoryResp, error)
	DeleteUserMemory(ctx context.Context, in *llmv1.DeleteUserMemoryReq) (*llmv1.DeleteUserMemoryResp, error)
	CreatePost(ctx context.Context, in *postv1.CreatePostRequest) (*postv1.CreatePostReply, error)
	UpdatePost(ctx context.Context, in *postv1.UpdatePostRequest) (*postv1.UpdatePostReply, error)
	GetPost(ctx context.Context, in *postv1.GetPostRequest) (*postv1.GetPostReply, error)
}
