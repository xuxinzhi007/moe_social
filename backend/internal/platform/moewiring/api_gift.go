package moewiring

import (
	"backend/internal/platform/appdb"
	giftapp "backend/internal/service/gift"
)

func GiftAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.gift_api_in_process")
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
