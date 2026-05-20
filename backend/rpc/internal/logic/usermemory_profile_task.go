package logic

import (
	"time"

	"backend/model"
	"backend/pkg/memory"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

const (
	profileCacheStaleAfter = 10 * time.Minute
	maxProfileTypes        = 20
	maxProfileSourceRows   = 600
)

func triggerUserMemoryProfileRebuildAsync(db *gorm.DB, userID uint, logger logx.Logger) {
	if db == nil || userID == 0 {
		return
	}
	go func() {
		if err := rebuildUserMemoryProfileCache(db, userID); err != nil {
			if logger != nil {
				logger.Errorf("rebuild user profile cache failed, user_id=%d err=%v", userID, err)
			}
		}
	}()
}

func ensureUserMemoryProfileCache(db *gorm.DB, userID uint, force bool) error {
	if db == nil || userID == 0 {
		return nil
	}
	if force {
		return rebuildUserMemoryProfileCache(db, userID)
	}
	var latest model.UserMemoryProfileCache
	err := db.Where("user_id = ?", userID).
		Order("updated_at desc").
		First(&latest).Error
	if err == nil {
		if time.Since(latest.UpdatedAt) < profileCacheStaleAfter {
			return nil
		}
	}
	if err != nil && err != gorm.ErrRecordNotFound {
		return err
	}
	return rebuildUserMemoryProfileCache(db, userID)
}

func rebuildUserMemoryProfileCache(db *gorm.DB, userID uint) error {
	var memories []model.UserMemory
	if err := db.
		Where("user_id = ?", userID).
		Order("updated_at desc").
		Limit(maxProfileSourceRows).
		Find(&memories).Error; err != nil {
		return err
	}

	profiles := memory.BuildProfiles(recordsFromUserMemoryModels(memories))
	if len(profiles) > maxProfileTypes {
		profiles = profiles[:maxProfileTypes]
	}

	return db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("user_id = ?", userID).
			Delete(&model.UserMemoryProfileCache{}).Error; err != nil {
			return err
		}
		if len(profiles) == 0 {
			return nil
		}
		now := time.Now()
		caches := make([]model.UserMemoryProfileCache, 0, len(profiles))
		for _, p := range profiles {
			conf := p.Confidence
			if conf < 0 {
				conf = 0
			}
			if conf > 1 {
				conf = 1
			}
			caches = append(caches, model.UserMemoryProfileCache{
				UserID:     userID,
				MemoryType: p.MemoryType,
				Summary:    p.Summary,
				ItemCount:  p.ItemCount,
				Confidence: conf,
				CreatedAt:  now,
				UpdatedAt:  now,
			})
		}
		return tx.Create(&caches).Error
	})
}
