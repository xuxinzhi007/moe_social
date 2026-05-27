package bootstrap

import (
	"backend/internal/platform/socialhook"
	"backend/pkg/achievement"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

// RegisterSocialAchievementHooks 将成就引擎挂到 socialhook，供 internal/service 进程内调用。
func RegisterSocialAchievementHooks() {
	socialhook.RegisterPostCreatedAchievementHook(func(db *gorm.DB, meta socialhook.PostCreatedMeta) []*super.AchievementUnlock {
		unlocks, err := achievement.ApplyEventAfterCommit(db, meta.UserID, achievement.Event{
			Type:             achievement.EventPostCreated,
			ImageCount:       meta.ImageCount,
			HasTopic:         meta.TopicTagCount > 0,
			ContentLen:       meta.ContentRuneLen,
			MoodTag:          meta.MoodTag,
			HasHandDraw:      meta.HasHandDraw,
			HandDrawApproved: meta.HandDrawApproved,
			Hour:             achievement.CurrentEventHour(),
		})
		if err != nil {
			logx.Errorf("成就处理失败（帖子仍会发布）: %v", err)
			return nil
		}
		return achievement.UnlocksToProto(unlocks)
	})

	socialhook.RegisterCommentCreatedAchievementHook(func(db *gorm.DB, userID uint) []*super.AchievementUnlock {
		unlocks, err := achievement.ApplyEventAfterCommit(db, userID, achievement.Event{
			Type: achievement.EventCommentCreated,
		})
		if err != nil {
			logx.Errorf("成就处理失败（评论仍会发布）: %v", err)
			return nil
		}
		return achievement.UnlocksToProto(unlocks)
	})

	socialhook.RegisterPostLikedAchievementHook(func(db *gorm.DB, meta socialhook.PostLikedMeta) {
		if _, err := achievement.ApplyEventAfterCommit(db, meta.PostAuthorUserID, achievement.Event{
			Type:          achievement.EventPostLiked,
			PostLikeCount: meta.PostLikeCount,
		}); err != nil {
			logx.Errorf("成就处理失败（点赞仍会成功）: %v", err)
		}
	})

	socialhook.RegisterGiftSentAchievementHook(func(db *gorm.DB, meta socialhook.GiftSentMeta) []*super.AchievementUnlock {
		unlocks, err := achievement.ApplyEventAfterCommit(db, meta.UserID, achievement.Event{
			Type: achievement.EventGiftSent, GiftCount: meta.GiftCount, GiftValue: meta.GiftValue,
		})
		if err != nil {
			logx.Errorf("成就处理失败（送礼仍会成功）: %v", err)
			return nil
		}
		return achievement.UnlocksToProto(unlocks)
	})
}
