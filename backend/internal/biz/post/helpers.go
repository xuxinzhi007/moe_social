package postbiz

import (
	"context"
	"encoding/json"
	"strconv"
	"strings"

	postv1 "backend/api/post/v1"
	"backend/model"
	"backend/rpc/pb/moe"
)

// LikedTargetIDSet 返回 targetIDs 中已被 userID 点赞的 ID。
func LikedTargetIDSet(ctx context.Context, st PostStore, userID uint, targetType string, targetIDs []uint) map[uint]bool {
	out := make(map[uint]bool)
	if st == nil || userID == 0 || len(targetIDs) == 0 {
		return out
	}
	found, err := st.WithContext(ctx).PluckLikedTargetIDs(ctx, userID, targetType, targetIDs)
	if err != nil {
		return out
	}
	for _, id := range found {
		out[id] = true
	}
	return out
}

func moderationStatusOrDefault(s string) string {
	if strings.TrimSpace(s) == "" {
		return "ok"
	}
	return s
}

// BuildProtoPost 将帖子与用户转为 moe.Post。
func BuildProtoPost(post model.Post, user model.User, isLiked bool) *moe.Post {
	var images []string
	if post.Images != "" {
		_ = json.Unmarshal([]byte(post.Images), &images)
	}

	username := "未知用户"
	avatar := "https://picsum.photos/150"
	if user.Username != "" {
		username = user.Username
	} else if user.Email != "" {
		username = user.Email
	}
	if user.Avatar != "" {
		avatar = user.Avatar
	}

	topicTags := make([]*moe.TopicTag, 0, len(post.TopicTags))
	for _, tag := range post.TopicTags {
		topicTags = append(topicTags, &moe.TopicTag{
			Id:        strconv.FormatUint(uint64(tag.ID), 10),
			Name:      tag.Name,
			Color:     tag.Color,
			CreatedAt: tag.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}

	return &moe.Post{
		Id:                strconv.FormatUint(uint64(post.ID), 10),
		UserId:            strconv.FormatUint(uint64(post.UserID), 10),
		UserName:          username,
		UserAvatar:        avatar,
		Content:           post.Content,
		Images:            images,
		TopicTags:         topicTags,
		Likes:             int32(post.Likes),
		Comments:          int32(post.Comments),
		IsLiked:           isLiked,
		CreatedAt:         post.CreatedAt.Format("2006-01-02 15:04:05"),
		HandDrawCard:      post.HandDrawCard,
		HandDrawThumbUrl:  post.HandDrawThumbURL,
		ModerationStatus:  moderationStatusOrDefault(post.ModerationStatus),
		AuthorIsBot:       user.IsBot,
		AuthorBotAgentKey: strings.TrimSpace(user.BotAgentKey),
	}
}

// ModerationStatusOrDefault 导出供其它 biz 使用。
func ModerationStatusOrDefault(s string) string {
	return moderationStatusOrDefault(s)
}

// BuildPostV1 将帖子与用户转为 post.v1 Post。
func BuildPostV1(post model.Post, user model.User, isLiked bool) *postv1.Post {
	return postv1.PostFromMoe(BuildProtoPost(post, user, isLiked))
}

// TopicTagsToPostV1 将话题标签转为 post.v1 TopicTag 列表。
func TopicTagsToPostV1(tags []model.TopicTag) []*postv1.TopicTag {
	out := make([]*postv1.TopicTag, 0, len(tags))
	for _, tag := range tags {
		out = append(out, &postv1.TopicTag{
			Id:        strconv.FormatUint(uint64(tag.ID), 10),
			Name:      tag.Name,
			Color:     tag.Color,
			CreatedAt: tag.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return out
}
