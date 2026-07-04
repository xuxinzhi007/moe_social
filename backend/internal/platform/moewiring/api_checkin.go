package moewiring

import (
	checkinapp "backend/internal/service/checkin"
	"backend/utils"
)

func CheckInAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.checkin_api_in_process")
}

func NewAPICheckInService() (*checkinapp.AppService, error) {
	if !CheckInAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	return checkinapp.New(db), nil
}
