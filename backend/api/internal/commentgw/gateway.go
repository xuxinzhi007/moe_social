package commentgw

import (
	"backend/api/internal/gwutil"
	"context"

	commentv1 "backend/api/comment/v1"
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
		out, err := g.local.GetPostComments(ctx, commentv1.GetPostCommentsRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return commentv1.GetPostCommentsReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) CreateComment(ctx context.Context, in *moe.CreateCommentReq, opts ...grpc.CallOption) (*moe.CreateCommentResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.CreateComment(ctx, commentv1.CreateCommentRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return commentv1.CreateCommentReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}

func (g *Gateway) LikeComment(ctx context.Context, in *moe.LikeCommentReq, opts ...grpc.CallOption) (*moe.LikeCommentResp, error) {
	if g != nil && g.local != nil {
		out, err := g.local.LikeComment(ctx, commentv1.LikeCommentRequestFromMoe(in))
		if err != nil {
			return nil, err
		}
		return commentv1.LikeCommentReplyToMoe(out), nil
	}
	return nil, gwutil.ErrUnavailable
}
