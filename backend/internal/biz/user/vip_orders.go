package userbiz

import (
	"context"
	"strconv"

	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// VipOrdersPage VIP 订单分页。
type VipOrdersPage struct {
	Page     int32
	PageSize int32
}

// ListVipOrders 用户 VIP 订单列表。
func ListVipOrders(ctx context.Context, store UserStore, userIDRaw string, page VipOrdersPage) ([]*moe.VipOrder, int32, error) {
	if store == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(userIDRaw, 10, 64)
	if err != nil || userID == 0 {
		return nil, 0, ErrInvalidArgument
	}
	p := page.Page
	if p <= 0 {
		p = 1
	}
	ps := page.PageSize
	if ps <= 0 {
		ps = 10
	}
	offset := int((p - 1) * ps)

	total, err := store.CountVipOrders(ctx, userID)
	if err != nil {
		return nil, 0, err
	}

	orders, err := store.ListVipOrdersWithPlan(ctx, userID, offset, int(ps))
	if err != nil {
		return nil, 0, err
	}

	out := make([]*moe.VipOrder, len(orders))
	for i, order := range orders {
		paidAt := ""
		if order.Status == "paid" {
			paidAt = order.UpdatedAt.Format("2006-01-02 15:04:05")
		}
		planName := ""
		if order.Plan.ID > 0 {
			planName = order.Plan.Name
		}
		out[i] = &moe.VipOrder{
			Id:        strconv.FormatUint(uint64(order.ID), 10),
			UserId:    userIDRaw,
			PlanId:    strconv.FormatUint(uint64(order.PlanID), 10),
			PlanName:  planName,
			Amount:    float32(order.Amount),
			Status:    order.Status,
			CreatedAt: order.CreatedAt.Format("2006-01-02 15:04:05"),
			PaidAt:    paidAt,
			OrderNo:   order.OrderNo,
		}
	}
	return out, int32(total), nil
}
