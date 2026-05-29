package adminbiz

import "errors"

var (
	ErrListVipOrders          = errors.New("list vip orders failed")
	ErrListGiftPurchaseOrders = errors.New("list gift purchase orders failed")
)
