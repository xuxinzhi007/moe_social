package utils

import (
	"backend/model"

	"gorm.io/gorm"
)

// BootstrapAchievementDefinitions 仅在成就定义表为空时写入默认成就。
func BootstrapAchievementDefinitions(db *gorm.DB) (int32, error) {
	if db == nil {
		return 0, nil
	}
	var count int64
	if err := db.Model(&model.AchievementDefinition{}).Count(&count).Error; err != nil {
		return 0, err
	}
	if count > 0 {
		return 0, nil
	}
	if err := SeedAchievementDefinitions(db); err != nil {
		return 0, err
	}
	if err := db.Model(&model.AchievementDefinition{}).Count(&count).Error; err != nil {
		return 0, err
	}
	return int32(count), nil
}
