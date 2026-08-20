package moewiring

import (
	"backend/internal/platform/appdb"
	battleapp "backend/internal/service/battle"
)

func BattleAPIInProcessEnabled() bool { return domainInProcessEnabled("moe.battle_api_in_process") }
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
