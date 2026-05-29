package httplegacy

import (
	"strconv"

	commentv1 "backend/api/comment/v1"
	postv1 "backend/api/post/v1"
	"backend/internal/legacy/types"
	"backend/rpc/pb/moe"
)

func topicTagsToProto(tags []types.TopicTag) []*postv1.TopicTag {
	out := make([]*postv1.TopicTag, 0, len(tags))
	for _, tag := range tags {
		out = append(out, &postv1.TopicTag{
			Id: tag.Id, Name: tag.Name, Color: tag.Color, CreatedAt: tag.CreatedAt,
		})
	}
	return out
}

func topicTagsToRPC(tags []types.TopicTag) []*moe.TopicTag {
	out := make([]*moe.TopicTag, 0, len(tags))
	for _, tag := range tags {
		out = append(out, &moe.TopicTag{
			Id: tag.Id, Name: tag.Name, Color: tag.Color, CreatedAt: tag.CreatedAt,
		})
	}
	return out
}

func postFromProto(p *postv1.Post) types.Post {
	if p == nil {
		return types.Post{}
	}
	return postFromRPC(postv1.PostToMoe(p))
}

func postFromRPC(p *moe.Post) types.Post {
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

func postsFromProto(posts []*postv1.Post) []types.Post {
	out := make([]types.Post, 0, len(posts))
	for _, p := range posts {
		out = append(out, postFromProto(p))
	}
	return out
}

func postsFromRPC(posts []*moe.Post) []types.Post {
	out := make([]types.Post, 0, len(posts))
	for _, p := range posts {
		out = append(out, postFromRPC(p))
	}
	return out
}

func commentsFromProto(comments []*commentv1.Comment) []types.Comment {
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

func commentsFromRPC(comments []*moe.Comment) []types.Comment {
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

func searchPostsLimit(pageSize int) int32 {
	limit := int32(pageSize)
	if limit <= 0 {
		limit = 10
	}
	if limit > 30 {
		limit = 30
	}
	return limit
}

func parseUint32ID(s string) uint64 {
	if s == "" {
		return 0
	}
	v, err := strconv.ParseUint(s, 10, 32)
	if err != nil {
		return 0
	}
	return v
}
