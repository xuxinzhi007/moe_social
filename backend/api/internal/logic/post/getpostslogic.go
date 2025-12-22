package post

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetPostsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetPostsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetPostsLogic {
	return &GetPostsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetPostsLogic) GetPosts(req *types.GetPostsReq) (resp *types.GetPostsResp, err error) {
	// 调用RPC服务获取帖子列表
	rpcResp, err := l.svcCtx.SuperRpcClient.GetPosts(l.ctx, &rpc.GetPostsReq{
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
	})
	if err != nil {
		l.Error("调用RPC服务失败:", err)
		return &types.GetPostsResp{
			BaseResp: common.HandleRPCError(err, ""),
			Data:     nil,
			Total:    0,
		}, nil
	}

	l.Debug("RPC响应，帖子数量:", len(rpcResp.Posts), "总数:", rpcResp.Total)

	// 转换为API响应格式
	respPosts := make([]types.Post, 0, len(rpcResp.Posts))
	for i, post := range rpcResp.Posts {
		contentPreview := post.Content
		if len(contentPreview) > 50 {
			contentPreview = contentPreview[:50] + "..."
		}
		l.Debug("转换帖子", i, "ID:", post.Id, "内容:", contentPreview)
		respPosts = append(respPosts, types.Post{
			Id:         post.Id,
			UserId:     post.UserId,
			UserName:   post.UserName,
			UserAvatar: post.UserAvatar,
			Content:    post.Content,
			Images:     post.Images,
			Likes:      int(post.Likes),
			Comments:   int(post.Comments),
			IsLiked:    post.IsLiked,
			CreatedAt:  post.CreatedAt,
		})
	}

	l.Debug("API响应，帖子数量:", len(respPosts), "总数:", rpcResp.Total)

	return &types.GetPostsResp{
		BaseResp: common.HandleRPCError(nil, "获取帖子列表成功"),
		Data:     respPosts,
		Total:    int(rpcResp.Total),
	}, nil
}
