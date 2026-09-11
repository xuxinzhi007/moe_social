package moewiring

import (
	"backend/internal/platform/appdb"
	checkinapp "backend/internal/service/checkin"
	"backend/pkg/conf"
)

func CheckInAPIInProcessEnabled() bool {
	return conf.DomainInProcess("checkin")
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
