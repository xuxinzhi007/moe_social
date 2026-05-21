package logic

import (
	"backend/model"
	"backend/pkg/memory"

	"gorm.io/gorm"
)

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

func upsertMemoryRelation(db *gorm.DB, userID uint, from, to, rel, source string, weight float64) error {
	if from == "" || to == "" || from == to {
		return nil
	}
	var row model.UserMemoryRelation
	err := db.Where("user_id = ? AND from_key = ? AND to_key = ? AND relation = ?", userID, from, to, rel).
		First(&row).Error
	if err == gorm.ErrRecordNotFound {
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
