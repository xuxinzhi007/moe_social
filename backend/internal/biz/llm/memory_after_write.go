package llmbiz

import (
	"context"
	"encoding/json"
	"errors"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/pkg/memory"
	"backend/pkg/memory/embed"

	"gorm.io/gorm"
)

const (
	profileCacheStaleAfter = 10 * time.Minute
	maxProfileTypes        = 20
	maxProfileSourceRows   = 600
)

func triggerAfterMemoryWrite(db *gorm.DB, userID uint, mem model.UserMemory, inferenceBaseURL string) {
	if db == nil || userID == 0 {
		return
	}
	go rebuildUserMemoryProfileCacheAsync(db, userID)
	go indexMemoryEmbeddingAsync(db, userID, mem.Key, mem.Value, mem.Source, inferenceBaseURL)
	go syncMemoryRelationsAsync(db, userID)
}

func rebuildUserMemoryProfileCacheAsync(db *gorm.DB, userID uint) {
	_ = rebuildUserMemoryProfileCache(db, userID)
}

func rebuildUserMemoryProfileCache(db *gorm.DB, userID uint) error {
	var memories []model.UserMemory
	if err := db.Where("user_id = ?", userID).Order("updated_at desc").Limit(maxProfileSourceRows).Find(&memories).Error; err != nil {
		return err
	}
	records := recordsFromUserMemoryModels(memories)
	facing := memory.FacingRecords(records)
	profileRecords := make([]memory.Record, 0, len(facing))
	for _, r := range facing {
		if memory.IsDailyNoteKey(r.Key) {
			continue
		}
		profileRecords = append(profileRecords, r)
	}
	profiles := memory.BuildProfiles(profileRecords)
	if len(profiles) > maxProfileTypes {
		profiles = profiles[:maxProfileTypes]
	}
	return db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("user_id = ?", userID).Delete(&model.UserMemoryProfileCache{}).Error; err != nil {
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

func indexMemoryEmbeddingAsync(db *gorm.DB, userID uint, key, value, source, inferenceBaseURL string) {
	if db == nil || userID == 0 {
		return
	}
	if memory.IsTechnical(key, source) || memory.IsDailyNoteKey(key) {
		return
	}
	value = strings.TrimSpace(value)
	if value == "" {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	text := key + ": " + value
	chain := embed.NewChain(embed.LoadProviders(inferenceBaseURL))
	vecs, provider, embedModel, err := chain.Embed(ctx, []string{text})
	if err != nil || len(vecs) == 0 {
		return
	}
	_ = upsertMemoryEmbedding(db, userID, key, text, provider, embedModel, vecs[0])
}

func syncMemoryRelationsAsync(db *gorm.DB, userID uint) {
	if db == nil || userID == 0 {
		return
	}
	var memories []model.UserMemory
	if err := db.Where("user_id = ?", userID).Order("updated_at desc").Limit(200).Find(&memories).Error; err != nil {
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
	for from, edges := range g.Adjacency() {
		for _, e := range edges {
			_ = upsertMemoryRelation(db, userID, from, e.ToKey, e.Relation, "inferred", e.Weight)
		}
	}
}

func recordsFromUserMemoryModels(list []model.UserMemory) []memory.Record {
	out := make([]memory.Record, 0, len(list))
	for _, m := range list {
		out = append(out, memory.Record{
			ID:          strconv.FormatUint(uint64(m.ID), 10),
			UserID:      strconv.FormatUint(uint64(m.UserID), 10),
			Key:         m.Key,
			Value:       m.Value,
			MemoryType:  m.MemoryType,
			Confidence:  m.Confidence,
			Source:      m.Source,
			SourceMsgID: m.SourceMsgID,
			SessionID:   m.SessionID,
			UpdatedAt:   m.UpdatedAt,
		})
	}
	return out
}

func upsertMemoryEmbedding(db *gorm.DB, userID uint, key, chunkText, provider, embedModel string, vec []float32) error {
	raw, err := encodeEmbeddingJSON(vec)
	if err != nil {
		return err
	}
	var row model.UserMemoryEmbedding
	err = db.Where("user_id = ? AND memory_key = ?", userID, key).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		row = model.UserMemoryEmbedding{
			UserID:    userID,
			MemoryKey: key,
			ChunkText: chunkText,
			Embedding: raw,
			Dim:       len(vec),
			Provider:  provider,
			Model:     embedModel,
		}
		return db.Create(&row).Error
	}
	if err != nil {
		return err
	}
	row.ChunkText = chunkText
	row.Embedding = raw
	row.Dim = len(vec)
	row.Provider = provider
	row.Model = embedModel
	return db.Save(&row).Error
}

func upsertMemoryRelation(db *gorm.DB, userID uint, from, to, rel, source string, weight float64) error {
	if from == "" || to == "" || from == to {
		return nil
	}
	var row model.UserMemoryRelation
	err := db.Where("user_id = ? AND from_key = ? AND to_key = ? AND relation = ?", userID, from, to, rel).
		First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		row = model.UserMemoryRelation{
			UserID:   userID,
			FromKey:  from,
			ToKey:    to,
			Relation: rel,
			Weight:   weight,
			Source:   source,
		}
		return db.Create(&row).Error
	}
	if err != nil {
		return err
	}
	row.Weight = weight
	row.Source = source
	return db.Save(&row).Error
}

func encodeEmbeddingJSON(vec []float32) (string, error) {
	doubles := make([]float64, len(vec))
	for i, v := range vec {
		doubles[i] = float64(v)
	}
	b, err := json.Marshal(doubles)
	return string(b), err
}
