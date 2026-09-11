package moewiring

import (
	"backend/internal/platform/appdb"
	giftapp "backend/internal/service/gift"
	"backend/pkg/conf"
)

func GiftAPIInProcessEnabled() bool {
	return conf.DomainInProcess("gift")
}

func NewAPIGiftService() (*giftapp.AppService, error) {
	if !GiftAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return giftapp.New(db), nil
}
