package postbiz

import (
	"context"
	"encoding/json"
	"errors"
	"strconv"

	"backend/model"

	"gorm.io/gorm"
)

// CreateInput 创建帖子参数。
type CreateInput struct {
	UserID                    string
	Content                   string
	Images                    []string
	TopicTagNames             []TopicTagInput
	HandDrawCard              string
	HandDrawThumbURL          string
	MoodTag                   string
	GroupID                   string
	HandDrawRequireModeration bool
}

// TopicTagInput 话题标签输入。
type TopicTagInput struct {
	Name  string
	Color string
}

// CreateResult 创建帖子结果（成就等副作用由 service 层处理）。
type CreateResult struct {
	Post              model.Post
	User              model.User
	TopicTags         []model.TopicTag
	Images            []string
	ModerationStatus  string
	HandDrawApproved  bool
	TopicTagCount     int
	ImageCount        int
	ContentRuneLen    int
}

// Create 创建帖子。
func Create(ctx context.Context, db *gorm.DB, in CreateInput) (CreateResult, error) {
	if db == nil {
		return CreateResult{}, gorm.ErrInvalidDB
	}
	if in.UserID == "" {
		return CreateResult{}, ErrEmptyUserID
	}
	if in.Content == "" && in.HandDrawCard == "" && len(in.Images) == 0 {
		return CreateResult{}, ErrEmptyPostContent
	}
	userID, err := strconv.ParseUint(in.UserID, 10, 32)
	if err != nil || userID == 0 {
		return CreateResult{}, ErrInvalidUserID
	}

	var user model.User
	if err := db.WithContext(ctx).Where("id = ?", userID).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return CreateResult{}, ErrUserNotFound
		}
		return CreateResult{}, err
	}
	if err := RequireGroupMember(db.WithContext(ctx), in.GroupID, uint(userID)); err != nil {
		return CreateResult{}, err
	}

	modStatus := "ok"
	if in.HandDrawCard != "" && in.HandDrawRequireModeration {
		modStatus = "pending"
	}

	tx := db.WithContext(ctx).Begin()
	if tx.Error != nil {
		return CreateResult{}, tx.Error
	}
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	post := model.Post{
		UserID:           uint(userID),
		Content:          in.Content,
		HandDrawCard:     in.HandDrawCard,
		HandDrawThumbURL: in.HandDrawThumbURL,
		ModerationStatus: modStatus,
		MoodTag:          in.MoodTag,
	}
	if len(in.Images) > 0 {
		imagesJSON, err := json.Marshal(in.Images)
		if err != nil {
			tx.Rollback()
			return CreateResult{}, err
		}
		post.Images = string(imagesJSON)
	}
	if err := tx.Create(&post).Error; err != nil {
		tx.Rollback()
		return CreateResult{}, err
	}

	var topicTags []model.TopicTag
	for _, tag := range in.TopicTagNames {
		var topicTag model.TopicTag
		if err := tx.Where("name = ?", tag.Name).FirstOrCreate(&topicTag, model.TopicTag{
			Name: tag.Name, Color: tag.Color,
		}).Error; err != nil {
			continue
		}
		topicTags = append(topicTags, topicTag)
	}
	if len(topicTags) > 0 {
		tx.Where("post_id = ?", post.ID).Delete(&model.PostTopic{})
		for _, tag := range topicTags {
			_ = tx.Create(&model.PostTopic{PostID: post.ID, TopicTagID: tag.ID}).Error
		}
	}

	if err := LinkPostToGroupTx(tx, in.GroupID, post.ID, uint(userID)); err != nil {
		tx.Rollback()
		return CreateResult{}, err
	}
	if err := tx.Commit().Error; err != nil {
		return CreateResult{}, err
	}

	handDrawApproved := in.HandDrawCard != "" && modStatus == "ok"
	return CreateResult{
		Post:             post,
		User:             user,
		TopicTags:        topicTags,
		Images:           in.Images,
		ModerationStatus: modStatus,
		HandDrawApproved: handDrawApproved,
		TopicTagCount:    len(topicTags),
		ImageCount:       len(in.Images),
		ContentRuneLen:   len([]rune(in.Content)),
	}, nil
}
