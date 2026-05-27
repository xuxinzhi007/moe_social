package moewiring

import (
	giftapp "backend/internal/service/gift"
	"backend/utils"
)

func GiftAPIInProcessEnabled() bool {
	if SingleProcessEnabled() || APIInProcessEnabled() {
		return boolOr(moeViper(), []string{"moe.gift_api_in_process"}, true)
	}
	return boolOr(moeViper(), []string{"moe.gift_api_in_process"}, false)
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
