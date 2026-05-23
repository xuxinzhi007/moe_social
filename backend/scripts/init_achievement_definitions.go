package scripts

import (
	"backend/utils"
)

// InitAchievementDefinitions seeds achievement_definitions (CLI helper).
func InitAchievementDefinitions() error {
	return utils.SeedAchievementDefinitions(utils.GetDB())
}
