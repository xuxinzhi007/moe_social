package moewiring

import (
	"backend/internal/platform/appdb"
	achievementapp "backend/internal/service/achievement"
)

func AchievementAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.achievement_api_in_process")
}

func NewAPIAchievementService() (*achievementapp.AppService, error) {
	if !AchievementAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return achievementapp.New(db), nil
}
