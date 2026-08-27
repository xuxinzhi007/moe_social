package moewiring

import (
	arenabiz "backend/internal/biz/arena"
	arenadata "backend/internal/data/arena"
	"backend/internal/platform/appdb"
	arenaapp "backend/internal/service/arena"
)

// NewAPIArenaService 装配星辉远征服务。
func NewAPIArenaService() (*arenaapp.AppService, error) {
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	repo := arenadata.NewRepo(db)
	uc := arenabiz.NewUsecase(repo)
	return arenaapp.New(uc), nil
}
