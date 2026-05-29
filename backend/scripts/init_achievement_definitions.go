package scripts

// DEPRECATED (2026-05-29): 请用 utils.SeedAchievementDefinitions / Admin 配置。

import (
	"backend/utils"
)

// InitAchievementDefinitions seeds achievement_definitions (CLI helper).
func InitAchievementDefinitions() error {
	return utils.SeedAchievementDefinitions(utils.GetDB())
}
