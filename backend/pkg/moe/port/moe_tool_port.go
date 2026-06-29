package port

import (
	"context"

	postv1 "backend/api/post/v1"
)

// MoeToolPort Moe 模块所需的 App 能力子集（进程内直连 service）。
type MoeToolPort interface {
	CreatePost(ctx context.Context, in *postv1.CreatePostRequest) (*postv1.CreatePostReply, error)
	UpdatePost(ctx context.Context, in *postv1.UpdatePostRequest) (*postv1.UpdatePostReply, error)
	GetPost(ctx context.Context, in *postv1.GetPostRequest) (*postv1.GetPostReply, error)
}
