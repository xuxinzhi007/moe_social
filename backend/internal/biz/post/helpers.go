package postbiz

import (
	"encoding/json"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// LikedTargetIDSet 返回 targetIDs 中已被 userID 点赞的 ID。
func LikedTargetIDSet(db *gorm.DB, userID uint, targetType string, targetIDs []uint) map[uint]bool {
	out := make(map[uint]bool)
	if userID == 0 || len(targetIDs) == 0 {
		return out
	}
	var found []uint
	if err := db.Model(&model.Like{}).
		Where("user_id = ? AND target_type = ? AND target_id IN ?", userID, targetType, targetIDs).
		Pluck("target_id", &found).Error; err != nil {
		return out
	}
	for _, id := range found {
		out[id] = true
	}
	return out
}

// ModerationVisibleScope 列表可见：非 rejected；pending 仅作者可见。
func ModerationVisibleScope(viewerUserID uint) func(db *gorm.DB) *gorm.DB {
	return func(db *gorm.DB) *gorm.DB {
		return db.Where("(moderation_status IS NULL OR moderation_status <> ?)", "rejected").
			Where("(moderation_status IS NULL OR moderation_status = '' OR moderation_status = 'ok') OR (moderation_status = 'pending' AND user_id = ?)", viewerUserID)
	}
}

func moderationStatusOrDefault(s string) string {
	if strings.TrimSpace(s) == "" {
		return "ok"
	}
	return s
}

// BuildProtoPost 将帖子与用户转为 super.Post。
func BuildProtoPost(post model.Post, user model.User, isLiked bool) *super.Post {
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

	topicTags := make([]*super.TopicTag, 0, len(post.TopicTags))
	for _, tag := range post.TopicTags {
		topicTags = append(topicTags, &super.TopicTag{
			Id:        strconv.FormatUint(uint64(tag.ID), 10),
			Name:      tag.Name,
			Color:     tag.Color,
			CreatedAt: tag.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}

	return &super.Post{
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
