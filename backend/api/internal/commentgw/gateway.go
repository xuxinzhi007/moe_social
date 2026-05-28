package commentgw

import (
	"backend/api/internal/gwutil"
	"context"

	commentapp "backend/internal/service/comment"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// Gateway Comment HTTP → biz 或 super RPC 回退。
type Gateway struct {
	local *commentapp.AppService
}

// New 构造网关。
func New(local *commentapp.AppService) *Gateway {
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

func (g *Gateway) GetPostComments(ctx context.Context, in *moe.GetPostCommentsReq, opts ...grpc.CallOption) (*moe.GetPostCommentsResp, error) {
	if g != nil && g.local != nil {
		return g.local.GetPostComments(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) CreateComment(ctx context.Context, in *moe.CreateCommentReq, opts ...grpc.CallOption) (*moe.CreateCommentResp, error) {
	if g != nil && g.local != nil {
		return g.local.CreateComment(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) LikeComment(ctx context.Context, in *moe.LikeCommentReq, opts ...grpc.CallOption) (*moe.LikeCommentResp, error) {
	if g != nil && g.local != nil {
		return g.local.LikeComment(ctx, in)
	}
	return nil, gwutil.ErrUnavailable
}
