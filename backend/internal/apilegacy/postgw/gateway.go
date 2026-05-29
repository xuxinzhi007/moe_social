package postgw

import (
	"backend/internal/apilegacy/gwutil"
	"context"

	postv1 "backend/api/post/v1"
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
		out, err := g.local.MoeSearchPosts(ctx, postv1.MoeSearchPostsRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return postv1.MoeSearchPostsReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetPost(ctx context.Context, in *moe.GetPostReq, opts ...grpc.CallOption) (*moe.GetPostResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetPost(ctx, postv1.GetPostRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return postv1.GetPostReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) GetPosts(ctx context.Context, in *moe.GetPostsReq, opts ...grpc.CallOption) (*moe.GetPostsResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.GetPosts(ctx, postv1.GetPostsRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return postv1.GetPostsReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) CreatePost(ctx context.Context, in *moe.CreatePostReq, opts ...grpc.CallOption) (*moe.CreatePostResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.CreatePost(ctx, postv1.CreatePostRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return postv1.CreatePostReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) LikePost(ctx context.Context, in *moe.LikePostReq, opts ...grpc.CallOption) (*moe.LikePostResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.LikePost(ctx, postv1.LikePostRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return postv1.LikePostReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) DeletePost(ctx context.Context, in *moe.DeletePostReq, opts ...grpc.CallOption) (*moe.DeletePostResp, error) {
	if g != nil && g.local != nil {
		_, err := g.local.DeletePost(ctx, postv1.DeletePostRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return &moe.DeletePostResp{}, nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) UpdatePost(ctx context.Context, in *moe.UpdatePostReq, opts ...grpc.CallOption) (*moe.UpdatePostResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.UpdatePost(ctx, postv1.UpdatePostRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return postv1.UpdatePostReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) ReportPost(ctx context.Context, in *moe.ReportPostReq, opts ...grpc.CallOption) (*moe.ReportPostResp, error) {
	if g != nil && g.local != nil {
		_, err := g.local.ReportPost(ctx, postv1.ReportPostRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return &moe.ReportPostResp{}, nil
	}
	return nil, gwutil.ErrUnavailable
}
