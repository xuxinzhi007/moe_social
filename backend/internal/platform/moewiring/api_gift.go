package moewiring

import (
	giftapp "backend/internal/service/gift"
	"backend/utils"
)

func GiftAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.gift_api_in_process")
}

func NewAPIGiftService() (*giftapp.AppService, error) {
	if !GiftAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	return giftapp.New(db), nil
}
