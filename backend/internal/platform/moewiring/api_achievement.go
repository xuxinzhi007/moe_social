package moewiring

import (
	achievementapp "backend/internal/service/achievement"
	"backend/utils"
)

func AchievementAPIInProcessEnabled() bool {
	if SingleProcessEnabled() || APIInProcessEnabled() {
		return boolOr(moeViper(), []string{"moe.achievement_api_in_process"}, true)
	}
	return boolOr(moeViper(), []string{"moe.achievement_api_in_process"}, false)
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
