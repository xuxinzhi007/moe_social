package post

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetPostLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetPostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetPostLogic {
	return &GetPostLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetPostLogic) GetPost(req *types.GetPostReq) (resp *types.GetPostResp, err error) {
	// 调用RPC服务获取帖子
	rpcResp, err := l.svcCtx.SuperRpcClient.GetPost(l.ctx, &super.GetPostReq{
		PostId: req.PostId,
	})
	if err != nil {
		return &types.GetPostResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 转换topic_tags格式
	apiTopicTags := make([]types.TopicTag, 0, len(rpcResp.Post.TopicTags))
	for _, tag := range rpcResp.Post.TopicTags {
		apiTopicTags = append(apiTopicTags, types.TopicTag{
			Id:    tag.Id,
			Name:  tag.Name,
			Color: tag.Color,
		})
	}

	// 转换为API响应格式
	return &types.GetPostResp{
		BaseResp: common.HandleRPCError(nil, "获取帖子成功"),
		Data: types.Post{
			Id:         rpcResp.Post.Id,
			UserId:     rpcResp.Post.UserId,
			UserName:   rpcResp.Post.UserName,
			UserAvatar: rpcResp.Post.UserAvatar,
			Content:    rpcResp.Post.Content,
			Images:     rpcResp.Post.Images,
			TopicTags:  apiTopicTags,
			Likes:      int(rpcResp.Post.Likes),
			Comments:   int(rpcResp.Post.Comments),
			IsLiked:    rpcResp.Post.IsLiked,
			CreatedAt:  rpcResp.Post.CreatedAt,
		},
	}, nil
}

