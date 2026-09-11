package moewiring

import (
	"backend/internal/platform/appdb"
	battleapp "backend/internal/service/battle"
	"backend/pkg/conf"
)

func BattleAPIInProcessEnabled() bool { return conf.DomainInProcess("battle") }
func NewAPIBattleService() (*battleapp.AppService, error) {
	if !BattleAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return battleapp.New(db), nil
}
