package llmbiz

import (
	"encoding/json"
	"strconv"

	"backend/model"
	"backend/pkg/memory"

	"gorm.io/gorm"
)

func parseUserIDUint(s string) (uint, error) {
	id, err := strconv.Atoi(s)
	if err != nil || id <= 0 {
		return 0, ErrMemoryInvalidUser
	}
	return uint(id), nil
}

func listMemoryEmbeddings(db *gorm.DB, userID uint) (map[string][]float32, error) {
	var rows []model.UserMemoryEmbedding
	if err := db.Where("user_id = ?", userID).Find(&rows).Error; err != nil {
		return nil, err
	}
	out := make(map[string][]float32, len(rows))
	for _, r := range rows {
		vec, err := decodeEmbeddingJSON(r.Embedding)
		if err != nil || len(vec) == 0 {
			continue
		}
		out[r.MemoryKey] = vec
	}
	return out, nil
}

func deleteEmbeddingsForUser(db *gorm.DB, userID uint) error {
	return db.Where("user_id = ?", userID).Delete(&model.UserMemoryEmbedding{}).Error
}

func decodeEmbeddingJSON(raw string) ([]float32, error) {
	var doubles []float64
	if err := json.Unmarshal([]byte(raw), &doubles); err != nil {
		return nil, err
	}
	out := make([]float32, len(doubles))
	for i, v := range doubles {
		out[i] = float32(v)
	}
	return out, nil
}

func listMemoryRelations(db *gorm.DB, userID uint) ([]memory.Relation, error) {
	var rows []model.UserMemoryRelation
	if err := db.Where("user_id = ?", userID).Find(&rows).Error; err != nil {
		return nil, err
	}
	out := make([]memory.Relation, 0, len(rows))
	for _, r := range rows {
		out = append(out, memory.Relation{
			FromKey:  r.FromKey,
			ToKey:    r.ToKey,
			Relation: r.Relation,
			Weight:   r.Weight,
		})
	}
	return out, nil
}
