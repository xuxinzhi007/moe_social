package post

import (
	"context"

	achlogic "backend/api/internal/logic/achievement"
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreatePostLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewCreatePostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreatePostLogic {
	return &CreatePostLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CreatePostLogic) CreatePost(req *types.CreatePostReq) (resp *types.CreatePostResp, err error) {
	// 转换topic_tags格式
	rpcTopicTags := make([]*moe.TopicTag, 0, len(req.TopicTags))
	for _, tag := range req.TopicTags {
		rpcTopicTags = append(rpcTopicTags, &moe.TopicTag{
			Id:        tag.Id,
			Name:      tag.Name,
			Color:     tag.Color,
			CreatedAt: tag.CreatedAt,
		})
	}

	// 调用RPC服务创建帖子
	rpcResp, err := l.svcCtx.PostGW.CreatePost(l.ctx, &moe.CreatePostReq{
		UserId:           req.UserId,
		Content:          req.Content,
		Images:           req.Images,
		TopicTags:        rpcTopicTags,
		HandDrawCard:     req.HandDrawCard,
		HandDrawThumbUrl: req.HandDrawThumbUrl,
		MoodTag:          req.MoodTag,
		GroupId:          req.GroupId,
	})
	if err != nil {
		return &types.CreatePostResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 转换topic_tags返回格式
	apiTopicTags := make([]types.TopicTag, 0, len(rpcResp.Post.TopicTags))
	for _, tag := range rpcResp.Post.TopicTags {
		apiTopicTags = append(apiTopicTags, types.TopicTag{
			Id:        tag.Id,
			Name:      tag.Name,
			Color:     tag.Color,
			CreatedAt: tag.CreatedAt,
		})
	}

	// 转换为API响应格式
	return &types.CreatePostResp{
		BaseResp:        common.HandleRPCError(nil, "创建帖子成功"),
		NewAchievements: achlogic.UnlocksFromRPC(rpcResp.NewAchievements),
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
