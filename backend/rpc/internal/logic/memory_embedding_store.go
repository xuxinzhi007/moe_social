package logic

import (
	"encoding/json"
	"strconv"

	"backend/model"

	"gorm.io/gorm"
)

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

func upsertMemoryEmbedding(db *gorm.DB, userID uint, key, chunkText, provider, embedModel string, vec []float32) error {
	raw, err := encodeEmbeddingJSON(vec)
	if err != nil {
		return err
	}
	var row model.UserMemoryEmbedding
	err = db.Where("user_id = ? AND memory_key = ?", userID, key).First(&row).Error
	if err == gorm.ErrRecordNotFound {
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

func deleteEmbeddingsForUser(db *gorm.DB, userID uint) error {
	return db.Where("user_id = ?", userID).Delete(&model.UserMemoryEmbedding{}).Error
}

func encodeEmbeddingJSON(vec []float32) (string, error) {
	doubles := make([]float64, len(vec))
	for i, v := range vec {
		doubles[i] = float64(v)
	}
	b, err := json.Marshal(doubles)
	return string(b), err
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

func parseUserIDUint(s string) (uint, error) {
	id, err := strconv.Atoi(s)
	if err != nil || id <= 0 {
		return 0, err
	}
	return uint(id), nil
}
