package logic

import (
	"sort"
	"strings"
	"time"

	"backend/model"

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

	type aggItem struct {
		count      int
		confidence float64
		values     []string
		seen       map[string]struct{}
	}
	grouped := map[string]*aggItem{}
	for _, m := range memories {
		key := strings.ToLower(strings.TrimSpace(m.Key))
		source := strings.ToLower(strings.TrimSpace(m.Source))
		if strings.HasPrefix(key, "device_info:") || source == "device_sync" {
			continue
		}
		mType := strings.TrimSpace(m.MemoryType)
		if mType == "" {
			mType = "general"
		}
		item, ok := grouped[mType]
		if !ok {
			item = &aggItem{seen: map[string]struct{}{}}
			grouped[mType] = item
		}
		item.count++
		item.confidence += m.Confidence
		v := strings.TrimSpace(m.Value)
		if v == "" {
			continue
		}
		if _, exists := item.seen[v]; exists {
			continue
		}
		item.seen[v] = struct{}{}
		if len(item.values) < 3 {
			item.values = append(item.values, v)
		}
	}

	type row struct {
		mType      string
		summary    string
		count      int
		confidence float64
	}
	rows := make([]row, 0, len(grouped))
	for mType, item := range grouped {
		if item.count == 0 || len(item.values) == 0 {
			continue
		}
		rows = append(rows, row{
			mType:      mType,
			summary:    strings.Join(item.values, "；"),
			count:      item.count,
			confidence: item.confidence / float64(item.count),
		})
	}
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].count == rows[j].count {
			return rows[i].confidence > rows[j].confidence
		}
		return rows[i].count > rows[j].count
	})
	if len(rows) > maxProfileTypes {
		rows = rows[:maxProfileTypes]
	}

	return db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("user_id = ?", userID).
			Delete(&model.UserMemoryProfileCache{}).Error; err != nil {
			return err
		}
		if len(rows) == 0 {
			return nil
		}
		now := time.Now()
		caches := make([]model.UserMemoryProfileCache, 0, len(rows))
		for _, r := range rows {
			conf := r.confidence
			if conf < 0 {
				conf = 0
			}
			if conf > 1 {
				conf = 1
			}
			caches = append(caches, model.UserMemoryProfileCache{
				UserID:     userID,
				MemoryType: r.mType,
				Summary:    r.summary,
				ItemCount:  r.count,
				Confidence: conf,
				CreatedAt:  now,
				UpdatedAt:  now,
			})
		}
		return tx.Create(&caches).Error
	})
}
