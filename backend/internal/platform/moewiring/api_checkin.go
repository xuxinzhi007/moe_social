package moewiring

import (
	"backend/internal/platform/appdb"
	checkinapp "backend/internal/service/checkin"
)

func CheckInAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.checkin_api_in_process")
}

func NewAPICheckInService() (*checkinapp.AppService, error) {
	if !CheckInAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return checkinapp.New(db), nil
}
