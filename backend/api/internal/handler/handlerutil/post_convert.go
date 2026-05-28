//go:build hybrid

package handlerutil

import (
	"strconv"

	"backend/api/internal/types"
	"backend/rpc/pb/moe"
)

// TopicTagsToRPC API topic tags → proto。
func TopicTagsToRPC(tags []types.TopicTag) []*moe.TopicTag {
	out := make([]*moe.TopicTag, 0, len(tags))
	for _, tag := range tags {
		out = append(out, &moe.TopicTag{
			Id: tag.Id, Name: tag.Name, Color: tag.Color, CreatedAt: tag.CreatedAt,
		})
	}
	return out
}

// PostFromRPC proto Post → API types。
func PostFromRPC(p *moe.Post) types.Post {
	if p == nil {
		return types.Post{}
	}
	apiTopicTags := make([]types.TopicTag, 0, len(p.GetTopicTags()))
	for _, tag := range p.GetTopicTags() {
		apiTopicTags = append(apiTopicTags, types.TopicTag{
			Id: tag.GetId(), Name: tag.GetName(), Color: tag.GetColor(), CreatedAt: tag.GetCreatedAt(),
		})
	}
	return types.Post{
		Id: p.GetId(), UserId: p.GetUserId(), UserName: p.GetUserName(), UserAvatar: p.GetUserAvatar(),
		Content: p.GetContent(), Images: p.GetImages(), TopicTags: apiTopicTags,
		Likes: int(p.GetLikes()), Comments: int(p.GetComments()), IsLiked: p.GetIsLiked(),
		CreatedAt: p.GetCreatedAt(), HandDrawCard: p.GetHandDrawCard(), HandDrawThumbUrl: p.GetHandDrawThumbUrl(),
		ModerationStatus: p.GetModerationStatus(), AuthorIsBot: p.GetAuthorIsBot(),
		AuthorBotAgentKey: p.GetAuthorBotAgentKey(),
	}
}

// PostsFromRPC proto Post 列表 → API types。
func PostsFromRPC(posts []*moe.Post) []types.Post {
	out := make([]types.Post, 0, len(posts))
	for _, p := range posts {
		out = append(out, PostFromRPC(p))
	}
	return out
}

// CommentsFromRPC proto Comment 列表 → API types。
func CommentsFromRPC(comments []*moe.Comment) []types.Comment {
	out := make([]types.Comment, 0, len(comments))
	for _, c := range comments {
		if c == nil {
			continue
		}
		out = append(out, types.Comment{
			Id: c.GetId(), PostId: c.GetPostId(), UserId: c.GetUserId(),
			UserName: c.GetUserName(), UserAvatar: c.GetUserAvatar(), Content: c.GetContent(),
			Likes: int(c.GetLikes()), IsLiked: c.GetIsLiked(), CreatedAt: c.GetCreatedAt(),
			ParentId: c.GetParentId(), ReplyToUserName: c.GetReplyToUserName(),
		})
	}
	return out
}

// SearchPostsLimit 检索 pageSize 上限。
func SearchPostsLimit(pageSize int) int32 {
	limit := int32(pageSize)
	if limit <= 0 {
		limit = 10
	}
	if limit > 30 {
		limit = 30
	}
	return limit
}

// ParseUint32ID 解析可选 uint ID 字符串。
func ParseUint32ID(s string) uint64 {
	if s == "" {
		return 0
	}
	v, err := strconv.ParseUint(s, 10, 32)
	if err != nil {
		return 0
	}
	return v
}
