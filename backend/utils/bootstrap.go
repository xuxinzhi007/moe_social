package utils

import (
	"backend/model"

	"gorm.io/gorm"
)

// BootstrapAdminAccount 仅在无管理员账号时创建默认超管（供 Admin 公开 bootstrap 调用）。
func BootstrapAdminAccount(db *gorm.DB) int32 {
	if db == nil {
		return 0
	}
	var count int64
	if err := db.Model(&model.AdminAccount{}).Count(&count).Error; err != nil || count > 0 {
		return 0
	}
	SeedAdminAccount(db)
	return 1
}

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
