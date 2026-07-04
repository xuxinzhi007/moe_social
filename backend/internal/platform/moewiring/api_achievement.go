package moewiring

import (
	achievementapp "backend/internal/service/achievement"
	"backend/utils"
)

func AchievementAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.achievement_api_in_process")
}

func NewAPIAchievementService() (*achievementapp.AppService, error) {
	if !AchievementAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	return achievementapp.New(db), nil
}
