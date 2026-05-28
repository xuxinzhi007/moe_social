package postgw

import (
	"backend/api/internal/gwutil"
	"context"

	postapp "backend/internal/service/post"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway Post HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *postapp.AppService
}

// New 构造网关。
func New(local *postapp.AppService) *Gateway {
	return &Gateway{local: local}
}

func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.local != nil {
		return "in_process"
	}
	return "none"
}

func (g *Gateway) MoeSearchPosts(ctx context.Context, in *moe.MoeSearchPostsReq, opts ...grpc.CallOption) (*moe.MoeSearchPostsResp, error) {
	if g != nil && g.local != nil {
		return g.local.MoeSearchPosts(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetPost(ctx context.Context, in *moe.GetPostReq, opts ...grpc.CallOption) (*moe.GetPostResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetPost(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetPosts(ctx context.Context, in *moe.GetPostsReq, opts ...grpc.CallOption) (*moe.GetPostsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetPosts(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) CreatePost(ctx context.Context, in *moe.CreatePostReq, opts ...grpc.CallOption) (*moe.CreatePostResp, error) {
	if g != nil && g.local != nil {
		return g.local.CreatePost(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) LikePost(ctx context.Context, in *moe.LikePostReq, opts ...grpc.CallOption) (*moe.LikePostResp, error) {
	if g != nil && g.local != nil {
		return g.local.LikePost(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) DeletePost(ctx context.Context, in *moe.DeletePostReq, opts ...grpc.CallOption) (*moe.DeletePostResp, error) {
	if g != nil && g.local != nil {
		return g.local.DeletePost(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpdatePost(ctx context.Context, in *moe.UpdatePostReq, opts ...grpc.CallOption) (*moe.UpdatePostResp, error) {
	if g != nil && g.local != nil {
		return g.local.UpdatePost(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ReportPost(ctx context.Context, in *moe.ReportPostReq, opts ...grpc.CallOption) (*moe.ReportPostResp, error) {
	if g != nil && g.local != nil {
		return g.local.ReportPost(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}
