package comment

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type LikeCommentLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewLikeCommentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *LikeCommentLogic {
	return &LikeCommentLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *LikeCommentLogic) LikeComment(req *types.LikeCommentReq) (resp *types.LikeCommentResp, err error) {
	// 调用RPC服务点赞评论
	rpcResp, err := l.svcCtx.SuperRpcClient.LikeComment(l.ctx, &super.LikeCommentReq{
		CommentId: req.CommentId,
		UserId:    req.UserId,
	})
	if err != nil {
		return &types.LikeCommentResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 转换为API响应格式
	return &types.LikeCommentResp{
		BaseResp: common.HandleRPCError(nil, "操作成功"),
		Data: types.Comment{
			Id:         rpcResp.Comment.Id,
			PostId:     rpcResp.Comment.PostId,
			UserId:     rpcResp.Comment.UserId,
			UserName:   rpcResp.Comment.UserName,
			UserAvatar: rpcResp.Comment.UserAvatar,
			Content:    rpcResp.Comment.Content,
			Likes:      int(rpcResp.Comment.Likes),
			IsLiked:    rpcResp.Comment.IsLiked,
			CreatedAt:  rpcResp.Comment.CreatedAt,
		},
	}, nil
}

