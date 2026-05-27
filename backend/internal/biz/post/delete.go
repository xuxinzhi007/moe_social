package postbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"backend/model"

	"gorm.io/gorm"
)

// Delete 软删除帖子（仅作者）。
func Delete(ctx context.Context, db *gorm.DB, postIDStr, userIDStr string) error {
	if db == nil {
		return gorm.ErrInvalidDB
	}
	postID, err := strconv.ParseUint(strings.TrimSpace(postIDStr), 10, 64)
	if err != nil || postID == 0 {
		return ErrInvalidPostID
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(userIDStr), 10, 64)
	if err != nil || userID == 0 {
		return ErrInvalidUserID
	}

	var p model.Post
	if err := db.WithContext(ctx).First(&p, postID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrPostNotFound
		}
		return err
	}
	if uint64(p.UserID) != userID {
		return ErrNotPostOwner
	}

	db.WithContext(ctx).Where("post_id = ?", p.ID).Delete(&model.PostTopic{})
	if err := db.WithContext(ctx).Delete(&p).Error; err != nil {
		return err
	}
	return nil
}
