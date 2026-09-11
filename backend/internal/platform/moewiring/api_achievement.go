package moewiring

import (
	"backend/internal/platform/appdb"
	achievementapp "backend/internal/service/achievement"
	"backend/pkg/conf"
)

func AchievementAPIInProcessEnabled() bool {
	return conf.DomainInProcess("achievement")
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
