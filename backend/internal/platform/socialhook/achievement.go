// Package socialhook 供 internal/service 注册 RPC 侧副作用（成就等），避免 import rpc/internal。
package socialhook

import (
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// PostCreatedMeta 发帖成就事件元数据。
type PostCreatedMeta struct {
	UserID           uint
	ImageCount       int
	TopicTagCount    int
	ContentRuneLen   int
	MoodTag          string
	HasHandDraw      bool
	HandDrawApproved bool
}

var postCreatedHook func(db *gorm.DB, meta PostCreatedMeta) []*super.AchievementUnlock

// RegisterPostCreatedAchievementHook 由 RPC bootstrap 注册成就处理。
func RegisterPostCreatedAchievementHook(fn func(db *gorm.DB, meta PostCreatedMeta) []*super.AchievementUnlock) {
	postCreatedHook = fn
}

// ApplyPostCreatedAchievements 发帖后触发成就（未注册时返回 nil）。
func ApplyPostCreatedAchievements(db *gorm.DB, meta PostCreatedMeta) []*super.AchievementUnlock {
	if postCreatedHook == nil {
		return nil
	}
	return postCreatedHook(db, meta)
}

var commentCreatedHook func(db *gorm.DB, userID uint) []*super.AchievementUnlock

// RegisterCommentCreatedAchievementHook 由 RPC bootstrap 注册成就处理。
func RegisterCommentCreatedAchievementHook(fn func(db *gorm.DB, userID uint) []*super.AchievementUnlock) {
	commentCreatedHook = fn
}

// ApplyCommentCreatedAchievements 评论后触发成就（未注册时返回 nil）。
func ApplyCommentCreatedAchievements(db *gorm.DB, userID uint) []*super.AchievementUnlock {
	if commentCreatedHook == nil {
		return nil
	}
	return commentCreatedHook(db, userID)
}

// PostLikedMeta 帖子被点赞成就事件元数据。
type PostLikedMeta struct {
	PostAuthorUserID uint
	PostLikeCount    int
}

var postLikedHook func(db *gorm.DB, meta PostLikedMeta)

// RegisterPostLikedAchievementHook 由 RPC bootstrap 注册成就处理。
func RegisterPostLikedAchievementHook(fn func(db *gorm.DB, meta PostLikedMeta)) {
	postLikedHook = fn
}

// ApplyPostLikedAchievements 帖子被点赞后触发成就（未注册时 no-op）。
func ApplyPostLikedAchievements(db *gorm.DB, meta PostLikedMeta) {
	if postLikedHook != nil {
		postLikedHook(db, meta)
	}
}

// GiftSentMeta 送礼成就事件元数据。
type GiftSentMeta struct {
	UserID    uint
	GiftCount int
	GiftValue float64
}

var giftSentHook func(db *gorm.DB, meta GiftSentMeta) []*super.AchievementUnlock

// RegisterGiftSentAchievementHook 由 RPC bootstrap 注册成就处理。
func RegisterGiftSentAchievementHook(fn func(db *gorm.DB, meta GiftSentMeta) []*super.AchievementUnlock) {
	giftSentHook = fn
}

// ApplyGiftSentAchievements 送礼后触发成就（未注册时返回 nil）。
func ApplyGiftSentAchievements(db *gorm.DB, meta GiftSentMeta) []*super.AchievementUnlock {
	if giftSentHook == nil {
		return nil
	}
	return giftSentHook(db, meta)
}
