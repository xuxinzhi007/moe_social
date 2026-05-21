package logic

import (
	"backend/model"
	"backend/pkg/memory"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

// syncMemoryRelationsForUser 根据当前用户记忆重建推断边（与 pkg/memory 规则一致，持久化供检索）。
func syncMemoryRelationsForUser(db *gorm.DB, userID uint, logger logx.Logger) {
	if db == nil || userID == 0 {
		return
	}
	var memories []model.UserMemory
	if err := db.Where("user_id = ?", userID).Order("updated_at desc").Limit(200).Find(&memories).Error; err != nil {
		if logger != nil {
			logger.Errorf("sync relations list memories failed user_id=%d: %v", userID, err)
		}
		return
	}
	records := make([]memory.Record, 0, len(memories))
	for _, m := range memories {
		if memory.IsTechnical(m.Key, m.Source) {
			continue
		}
		records = append(records, memory.Record{
			Key:        m.Key,
			Value:      m.Value,
			MemoryType: m.MemoryType,
			Confidence: m.Confidence,
			Source:     m.Source,
		})
	}
	g := memory.BuildMemoryGraph(records, nil)
	_ = db.Where("user_id = ? AND source = ?", userID, "inferred").Delete(&model.UserMemoryRelation{}).Error
	count := 0
	for from, edges := range g.Adjacency() {
		for _, e := range edges {
			if err := upsertMemoryRelation(db, userID, from, e.ToKey, e.Relation, "inferred", e.Weight); err != nil && logger != nil {
				logger.Errorf("upsert relation failed: %v", err)
				continue
			}
			count++
		}
	}
	if logger != nil && count > 0 {
		logger.Infof("memory relations synced user_id=%d edges=%d", userID, count)
	}
}

// triggerMemoryRelationsSyncAsync 在记忆变更后异步刷新图谱边。
func triggerMemoryRelationsSyncAsync(db *gorm.DB, userID uint, logger logx.Logger) {
	if db == nil || userID == 0 {
		return
	}
	go syncMemoryRelationsForUser(db, userID, logger)
}
