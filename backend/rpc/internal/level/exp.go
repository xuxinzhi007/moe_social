package level

import (
	"fmt"

	"backend/model"

	"gorm.io/gorm"
)

// AddExperienceResult holds level update outcome.
type AddExperienceResult struct {
	LevelUp  bool
	OldLevel int
	NewLevel int
}

// AddExperience updates user level and writes an exp log within tx.
func AddExperience(tx *gorm.DB, userID uint, delta int, source, sourceID, description string) (*AddExperienceResult, error) {
	if delta <= 0 {
		return &AddExperienceResult{}, nil
	}

	var userLevel model.UserLevel
	if err := tx.Where("user_id = ?", userID).First(&userLevel).Error; err != nil {
		userLevel = model.UserLevel{
			UserID:     userID,
			Level:      1,
			Experience: 0,
			TotalExp:   0,
		}
		if err := tx.Create(&userLevel).Error; err != nil {
			return nil, fmt.Errorf("创建用户等级失败: %w", err)
		}
	}

	oldLevel := userLevel.Level
	userLevel.Experience += delta
	userLevel.TotalExp += delta
	userLevel.Level = CalculateLevel(tx, userLevel.TotalExp)

	if err := tx.Save(&userLevel).Error; err != nil {
		return nil, fmt.Errorf("更新用户等级失败: %w", err)
	}

	expLog := model.ExpLog{
		UserID:      userID,
		ExpChange:   delta,
		Source:      source,
		SourceID:    sourceID,
		Description: description,
	}
	if err := tx.Create(&expLog).Error; err != nil {
		return nil, fmt.Errorf("创建经验日志失败: %w", err)
	}

	return &AddExperienceResult{
		LevelUp:  userLevel.Level > oldLevel,
		OldLevel: oldLevel,
		NewLevel: userLevel.Level,
	}, nil
}

// CalculateLevel returns level from total experience.
func CalculateLevel(tx *gorm.DB, totalExp int) int {
	var configs []model.LevelConfig
	if err := tx.Order("level ASC").Find(&configs).Error; err != nil || len(configs) == 0 {
		return defaultCalculateLevel(totalExp)
	}
	for _, config := range configs {
		if totalExp < config.MaxExp {
			return config.Level
		}
	}
	return configs[len(configs)-1].Level
}

func defaultCalculateLevel(totalExp int) int {
	switch {
	case totalExp < 100:
		return 1
	case totalExp < 500:
		return 2
	case totalExp < 2000:
		return 3
	case totalExp < 5000:
		return 4
	default:
		return 5
	}
}
