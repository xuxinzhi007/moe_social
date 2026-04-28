package post

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdatePostLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewUpdatePostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdatePostLogic {
	return &UpdatePostLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UpdatePostLogic) UpdatePost(req *types.UpdatePostReq) (resp *types.UpdatePostResp, err error) {
	rpcTopicTags := make([]*super.TopicTag, 0, len(req.TopicTags))
	for _, tag := range req.TopicTags {
		rpcTopicTags = append(rpcTopicTags, &super.TopicTag{
			Id:    tag.Id,
			Name:  tag.Name,
			Color: tag.Color,
		})
	}

	rpcResp, err := l.svcCtx.SuperRpcClient.UpdatePost(l.ctx, &super.UpdatePostReq{
		PostId:          req.PostId,
		UserId:          req.UserId,
		Content:         req.Content,
		Images:          req.Images,
		TopicTags:       rpcTopicTags,
		HandDrawCard:    req.HandDrawCard,
		HandDrawThumbUrl: req.HandDrawThumbUrl,
	})
	if err != nil {
		return &types.UpdatePostResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	apiTopicTags := make([]types.TopicTag, 0, len(rpcResp.Post.TopicTags))
	for _, tag := range rpcResp.Post.TopicTags {
		apiTopicTags = append(apiTopicTags, types.TopicTag{
			Id:    tag.Id,
			Name:  tag.Name,
			Color: tag.Color,
		})
	}

	return &types.UpdatePostResp{
		BaseResp: common.HandleRPCError(nil, "更新帖子成功"),
		Data: types.Post{
			Id:               rpcResp.Post.Id,
			UserId:           rpcResp.Post.UserId,
			UserName:         rpcResp.Post.UserName,
			UserAvatar:       rpcResp.Post.UserAvatar,
			Content:          rpcResp.Post.Content,
			Images:           rpcResp.Post.Images,
			TopicTags:        apiTopicTags,
			Likes:            int(rpcResp.Post.Likes),
			Comments:         int(rpcResp.Post.Comments),
			IsLiked:          rpcResp.Post.IsLiked,
			CreatedAt:        rpcResp.Post.CreatedAt,
			HandDrawCard:     rpcResp.Post.HandDrawCard,
			HandDrawThumbUrl: rpcResp.Post.HandDrawThumbUrl,
			ModerationStatus: rpcResp.Post.ModerationStatus,
		},
	}, nil
}
