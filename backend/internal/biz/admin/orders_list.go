package adminbiz

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// ListVipOrders Admin VIP 订单列表。
func ListVipOrders(ctx context.Context, db *gorm.DB, in *super.AdminListVipOrdersReq) (*super.AdminListVipOrdersResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}

	q := db.WithContext(ctx).Model(&model.VipOrder{})
	if uid := strings.TrimSpace(in.GetUserId()); uid != "" {
		if n, err := strconv.ParseUint(uid, 10, 64); err == nil && n > 0 {
			q = q.Where("user_id = ?", n)
		}
	}
	if st := strings.TrimSpace(in.GetStatus()); st != "" {
		q = q.Where("status = ?", st)
	}
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		q = q.Where("order_no LIKE ?", "%"+kw+"%")
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListVipOrders, err)
	}

	var rows []model.VipOrder
	offset := int((page - 1) * pageSize)
	if err := q.Preload("Plan").Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListVipOrders, err)
	}

	out := make([]*super.VipOrder, len(rows))
	for i, order := range rows {
		paidAt := ""
		if order.Status == "paid" {
			paidAt = order.UpdatedAt.Format("2006-01-02 15:04:05")
		}
		planName := ""
		if order.Plan.ID > 0 {
			planName = order.Plan.Name
		}
		out[i] = &super.VipOrder{
			Id:        strconv.FormatUint(uint64(order.ID), 10),
			UserId:    strconv.FormatUint(uint64(order.UserID), 10),
			PlanId:    strconv.FormatUint(uint64(order.PlanID), 10),
			PlanName:  planName,
			Amount:    float32(order.Amount),
			Status:    order.Status,
			CreatedAt: order.CreatedAt.Format("2006-01-02 15:04:05"),
			PaidAt:    paidAt,
			OrderNo:   order.OrderNo,
		}
	}
	return &super.AdminListVipOrdersResp{Orders: out, Total: int32(total)}, nil
}

// ListGiftPurchaseOrders Admin 礼物购买订单列表。
func ListGiftPurchaseOrders(ctx context.Context, db *gorm.DB, in *super.AdminListGiftPurchaseOrdersReq) (*super.AdminListGiftPurchaseOrdersResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}

	q := db.WithContext(ctx).Model(&model.GiftPurchaseOrder{})
	if uid := strings.TrimSpace(in.GetUserId()); uid != "" {
		if n, err := strconv.ParseUint(uid, 10, 64); err == nil && n > 0 {
			q = q.Where("user_id = ?", n)
		}
	}
	if st := strings.TrimSpace(in.GetStatus()); st != "" {
		q = q.Where("status = ?", st)
	}
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("order_no LIKE ? OR gift_name LIKE ?", like, like)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListGiftPurchaseOrders, err)
	}

	var rows []model.GiftPurchaseOrder
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListGiftPurchaseOrders, err)
	}

	out := make([]*super.GiftPurchaseOrder, 0, len(rows))
	for _, o := range rows {
		out = append(out, &super.GiftPurchaseOrder{
			Id:          strconv.FormatUint(uint64(o.ID), 10),
			UserId:      strconv.FormatUint(uint64(o.UserID), 10),
			OrderNo:     o.OrderNo,
			GiftId:      strconv.FormatUint(uint64(o.GiftID), 10),
			GiftName:    o.GiftName,
			Quantity:    int32(o.Quantity),
			UnitPrice:   o.UnitPrice,
			TotalAmount: o.TotalAmount,
			PayMethod:   o.PayMethod,
			Status:      o.Status,
			CreatedAt:   o.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return &super.AdminListGiftPurchaseOrdersResp{Orders: out, Total: int32(total)}, nil
}
