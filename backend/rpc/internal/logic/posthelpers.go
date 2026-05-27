package logic

import (
	"backend/model"
	postbiz "backend/internal/biz/post"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

func LikedTargetIDSet(db *gorm.DB, userID uint, targetType string, targetIDs []uint) map[uint]bool {
	return postbiz.LikedTargetIDSet(db, userID, targetType, targetIDs)
}

func moderationVisibleScope(viewerUserID uint) func(db *gorm.DB) *gorm.DB {
	return postbiz.ModerationVisibleScope(viewerUserID)
}

func moderationStatusOrDefault(s string) string {
	return postbiz.ModerationStatusOrDefault(s)
}

func buildSuperPost(post model.Post, user model.User, isLiked bool) *super.Post {
	return postbiz.BuildProtoPost(post, user, isLiked)
}
