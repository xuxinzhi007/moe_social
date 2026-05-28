package community

import (
	"strconv"

	"backend/api/internal/types"
	"backend/rpc/pb/moe"
)

func rpcPostToTypes(p *moe.Post) types.Post {
	if p == nil {
		return types.Post{}
	}
	apiTopicTags := make([]types.TopicTag, 0, len(p.TopicTags))
	for _, tag := range p.TopicTags {
		apiTopicTags = append(apiTopicTags, types.TopicTag{
			Id:        tag.Id,
			Name:      tag.Name,
			Color:     tag.Color,
			CreatedAt: tag.CreatedAt,
		})
	}
	return types.Post{
		Id:               p.Id,
		UserId:           p.UserId,
		UserName:         p.UserName,
		UserAvatar:       p.UserAvatar,
		Content:          p.Content,
		Images:           p.Images,
		TopicTags:        apiTopicTags,
		Likes:            int(p.Likes),
		Comments:         int(p.Comments),
		IsLiked:          p.IsLiked,
		CreatedAt:        p.CreatedAt,
		HandDrawCard:     p.HandDrawCard,
		HandDrawThumbUrl: p.HandDrawThumbUrl,
		ModerationStatus: p.ModerationStatus,
	}
}

func rpcGroupPostToTypes(gp *moe.GroupPost) types.GroupPost {
	if gp == nil {
		return types.GroupPost{}
	}
	return types.GroupPost{
		Id:        strconv.FormatUint(gp.Id, 10),
		GroupId:   strconv.FormatUint(gp.GroupId, 10),
		PostId:    strconv.FormatUint(gp.PostId, 10),
		Post:      rpcPostToTypes(gp.Post),
		CreatedAt: gp.CreatedAt,
	}
}
