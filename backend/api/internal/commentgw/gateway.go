package commentgw

import (
	"context"

	commentapp "backend/internal/service/comment"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway Comment HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *commentapp.AppService
	super moe.SuperClient
}

// New 构造网关。
func New(local *commentapp.AppService, legacy moe.SuperClient) *Gateway {
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

func (g *Gateway) GetPostComments(ctx context.Context, in *moe.GetPostCommentsReq, opts ...grpc.CallOption) (*moe.GetPostCommentsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetPostComments(ctx, in)
	}
	return g.super.GetPostComments(ctx, in, opts...)
}

func (g *Gateway) CreateComment(ctx context.Context, in *moe.CreateCommentReq, opts ...grpc.CallOption) (*moe.CreateCommentResp, error) {
	if g != nil && g.local != nil {
		return g.local.CreateComment(ctx, in)
	}
	return g.super.CreateComment(ctx, in, opts...)
}

func (g *Gateway) LikeComment(ctx context.Context, in *moe.LikeCommentReq, opts ...grpc.CallOption) (*moe.LikeCommentResp, error) {
	if g != nil && g.local != nil {
		return g.local.LikeComment(ctx, in)
	}
	return g.super.LikeComment(ctx, in, opts...)
}
