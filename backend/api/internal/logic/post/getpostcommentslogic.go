package post

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetPostCommentsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetPostCommentsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetPostCommentsLogic {
	return &GetPostCommentsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetPostCommentsLogic) GetPostComments(req *types.GetPostCommentsReq) (resp *types.GetPostCommentsResp, err error) {
	// 调用RPC服务获取帖子评论
	rpcResp, err := l.svcCtx.CommentGW.GetPostComments(l.ctx, &moe.GetPostCommentsReq{
		PostId:        req.PostId,
		Page:          int32(req.Page),
		PageSize:      int32(req.PageSize),
		ViewerUserId:  req.ViewerUserId,
	})
	if err != nil {
		return &types.GetPostCommentsResp{
			BaseResp: common.HandleRPCError(err, ""),
			Data:     nil,
			Total:    0,
		}, nil
	}

	// 转换为API响应格式
	respComments := make([]types.Comment, 0, len(rpcResp.Comments))
	for _, comment := range rpcResp.Comments {
		respComments = append(respComments, types.Comment{
			Id:              comment.Id,
			PostId:          comment.PostId,
			UserId:          comment.UserId,
			UserName:        comment.UserName,
			UserAvatar:      comment.UserAvatar,
			Content:         comment.Content,
			Likes:           int(comment.Likes),
			IsLiked:         comment.IsLiked,
			CreatedAt:       comment.CreatedAt,
			ParentId:        comment.ParentId,
			ReplyToUserName: comment.ReplyToUserName,
		})
	}

	return &types.GetPostCommentsResp{
		BaseResp: common.HandleRPCError(nil, "获取评论列表成功"),
		Data:     respComments,
		Total:    int(rpcResp.Total),
	}, nil
}

