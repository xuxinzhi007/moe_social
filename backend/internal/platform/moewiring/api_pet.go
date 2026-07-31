package moewiring

import (
	petbiz "backend/internal/biz/pet"
	petdata "backend/internal/data/pet"
	petapp "backend/internal/service/pet"
	"backend/utils"
)

// NewAPIPetService 装配养成服务。
func NewAPIPetService() (*petapp.AppService, error) {
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	repo := petdata.NewRepo(db)
	uc := petbiz.NewUsecase(repo)
	return petapp.New(uc), nil
}
