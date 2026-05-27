package postgw

import (
	"context"

	postapp "backend/internal/service/post"
	"backend/rpc/pb/super"

	"google.golang.org/grpc"
)

// Gateway Post HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *postapp.AppService
	super super.SuperClient
}

// New 构造网关。
func New(local *postapp.AppService, legacy super.SuperClient) *Gateway {
	return &Gateway{local: local, super: legacy}
}

func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	if g.super != nil {
		return "super"
	}
	return "none"
}

func (g *Gateway) MoeSearchPosts(ctx context.Context, in *super.MoeSearchPostsReq, opts ...grpc.CallOption) (*super.MoeSearchPostsResp, error) {
	if g != nil && g.local != nil {
		return g.local.MoeSearchPosts(ctx, in)
	}
	return g.super.MoeSearchPosts(ctx, in, opts...)
}

func (g *Gateway) GetPost(ctx context.Context, in *super.GetPostReq, opts ...grpc.CallOption) (*super.GetPostResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetPost(ctx, in)
	}
	return g.super.GetPost(ctx, in, opts...)
}

func (g *Gateway) GetPosts(ctx context.Context, in *super.GetPostsReq, opts ...grpc.CallOption) (*super.GetPostsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetPosts(ctx, in)
	}
	return g.super.GetPosts(ctx, in, opts...)
}

func (g *Gateway) CreatePost(ctx context.Context, in *super.CreatePostReq, opts ...grpc.CallOption) (*super.CreatePostResp, error) {
	if g != nil && g.local != nil {
		return g.local.CreatePost(ctx, in)
	}
	return g.super.CreatePost(ctx, in, opts...)
}

func (g *Gateway) LikePost(ctx context.Context, in *super.LikePostReq, opts ...grpc.CallOption) (*super.LikePostResp, error) {
	if g != nil && g.local != nil {
		return g.local.LikePost(ctx, in)
	}
	return g.super.LikePost(ctx, in, opts...)
}

func (g *Gateway) DeletePost(ctx context.Context, in *super.DeletePostReq, opts ...grpc.CallOption) (*super.DeletePostResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeletePost(ctx, in)
	}
	return g.super.DeletePost(ctx, in, opts...)
}

func (g *Gateway) UpdatePost(ctx context.Context, in *super.UpdatePostReq, opts ...grpc.CallOption) (*super.UpdatePostResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdatePost(ctx, in)
	}
	return g.super.UpdatePost(ctx, in, opts...)
}

func (g *Gateway) ReportPost(ctx context.Context, in *super.ReportPostReq, opts ...grpc.CallOption) (*super.ReportPostResp, error) {
	if g != nil && g.local != nil {
		return g.local.ReportPost(ctx, in)
	}
	return g.super.ReportPost(ctx, in, opts...)
}
