package moewiring

import (
	petbiz "backend/internal/biz/pet"
	petdata "backend/internal/data/pet"
	"backend/internal/platform/appdb"
	petapp "backend/internal/service/pet"
)

// NewAPIPetService 装配养成服务。
func NewAPIPetService() (*petapp.AppService, error) {
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	repo := petdata.NewRepo(db)
	uc := petbiz.NewUsecase(repo)
	return petapp.New(uc), nil
}
