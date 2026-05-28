package userbiz

import (
	"context"
	"errors"
	"strconv"
	"time"

	"backend/model"
	"backend/pkg/achievement"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// CreateVipOrder 钱包购买 VIP 套餐。
func CreateVipOrder(ctx context.Context, db *gorm.DB, in *moe.CreateVipOrderReq) (*moe.CreateVipOrderResp, error) {
	var order model.VipOrder
	var paidUserID uint
	err := db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var user model.User
		if err := tx.Set("gorm:query_option", "FOR UPDATE").First(&user, in.GetUserId()).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrNotFound
			}
			return err
		}
		var plan model.VipPlan
		if err := tx.First(&plan, in.GetPlanId()).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrVipPlanNotFound
			}
			return err
		}
		if user.Balance < plan.Price {
			return ErrInsufficientBalance
		}

		orderNo := "ORD" + strconv.FormatInt(time.Now().UnixNano(), 10)
		now := time.Now()
		vipEnd := now.AddDate(0, 0, plan.Duration)

		if err := tx.Model(&model.VipOrder{}).Where("user_id = ?", user.ID).Update("is_active", false).Error; err != nil {
			return err
		}

		order = model.VipOrder{
			UserID:    user.ID,
			PlanID:    plan.ID,
			OrderNo:   orderNo,
			Amount:    plan.Price,
			Status:    "paid",
			PayMethod: "wallet",
			IsActive:  true,
			StartAt:   &now,
			EndAt:     &vipEnd,
		}
		if err := tx.Create(&order).Error; err != nil {
			return err
		}

		newBalance := user.Balance - plan.Price
		if err := tx.Model(&user).UpdateColumn("balance", newBalance).Error; err != nil {
			return err
		}

		transaction := model.Transaction{
			UserID:      user.ID,
			Amount:      plan.Price,
			Type:        "consume",
			Status:      "success",
			Description: "购买VIP套餐：" + plan.Name,
		}
		if err := tx.Create(&transaction).Error; err != nil {
			return err
		}

		user.IsVip = true
		user.VipStartAt = &now
		user.VipEndAt = &vipEnd
		if err := tx.Save(&user).Error; err != nil {
			return err
		}
		order.Plan = plan
		paidUserID = user.ID
		return nil
	})
	if err != nil {
		return nil, err
	}

	var achUnlocks []achievement.UnlockResult
	if paidUserID > 0 {
		unlocks, achErr := achievement.ApplyEventAfterCommit(db, paidUserID, achievement.Event{Type: achievement.EventVipActivated})
		if achErr == nil {
			achUnlocks = unlocks
		}
	}

	return &moe.CreateVipOrderResp{
		NewAchievements: achievement.UnlocksToProto(achUnlocks),
		Order: &moe.VipOrder{
			Id:        strconv.FormatUint(uint64(order.ID), 10),
			UserId:    in.GetUserId(),
			PlanId:    strconv.FormatUint(uint64(order.PlanID), 10),
			PlanName:  order.Plan.Name,
			Amount:    float32(order.Amount),
			Status:    order.Status,
			CreatedAt: order.CreatedAt.Format("2006-01-02 15:04:05"),
			PaidAt:    order.UpdatedAt.Format("2006-01-02 15:04:05"),
			OrderNo:   order.OrderNo,
		},
	}, nil
}

// UpdateUserVip 管理端设置 VIP 状态。
func UpdateUserVip(ctx context.Context, db *gorm.DB, in *moe.UpdateUserVipReq) (*moe.UpdateUserVipResp, error) {
	var user model.User
	if err := db.WithContext(ctx).First(&user, in.GetUserId()).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}

	if in.GetIsVip() {
		vipExpires, err := time.Parse("2006-01-02 15:04:05", in.GetVipExpires())
		if err != nil {
			return nil, ErrInvalidArgument
		}
		_ = db.WithContext(ctx).Model(&model.VipOrder{}).Where("user_id = ?", user.ID).Update("is_active", false)
		vipStart := time.Now()
		orderNo := "VIP_" + strconv.FormatInt(time.Now().Unix(), 10) + "_" + strconv.Itoa(int(user.ID))
		vipOrder := model.VipOrder{
			UserID:    user.ID,
			PlanID:    1,
			OrderNo:   orderNo,
			Amount:    0,
			Status:    "paid",
			PayMethod: "system",
			IsActive:  true,
			StartAt:   &vipStart,
			EndAt:     &vipExpires,
		}
		if err := db.WithContext(ctx).Create(&vipOrder).Error; err != nil {
			return nil, err
		}
		user.IsVip = true
		user.VipStartAt = &vipStart
		user.VipEndAt = &vipExpires
	} else {
		user.IsVip = false
		user.VipStartAt = nil
		user.VipEndAt = nil
		_ = db.WithContext(ctx).Model(&model.VipOrder{}).Where("user_id = ?", user.ID).Update("is_active", false)
	}

	if err := db.WithContext(ctx).Save(&user).Error; err != nil {
		return nil, err
	}
	return &moe.UpdateUserVipResp{User: ModelToProto(&user)}, nil
}

// SyncUserVipStatus 按过期时间同步 VIP 标记。
func SyncUserVipStatus(ctx context.Context, db *gorm.DB, in *moe.SyncUserVipStatusReq) (*moe.SyncUserVipStatusResp, error) {
	var user model.User
	if err := db.WithContext(ctx).First(&user, in.GetUserId()).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	isVip := user.IsVip
	vipEndAt := ""
	if user.VipEndAt != nil {
		vipEndAt = user.VipEndAt.Format("2006-01-02 15:04:05")
		if user.VipEndAt.Before(time.Now()) {
			isVip = false
			user.IsVip = false
			_ = db.WithContext(ctx).Save(&user)
		}
	}
	return &moe.SyncUserVipStatusResp{IsVip: isVip, ExpiresAt: vipEndAt}, nil
}

// UpdateAutoRenew 占位（模型暂无字段）。
func UpdateAutoRenew(ctx context.Context, db *gorm.DB, in *moe.UpdateAutoRenewReq) (*moe.UpdateAutoRenewResp, error) {
	var user model.User
	if err := db.WithContext(ctx).First(&user, in.GetUserId()).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &moe.UpdateAutoRenewResp{}, nil
}

// GetVipRecords 分页 VIP 订单记录。
func GetVipRecords(ctx context.Context, db *gorm.DB, in *moe.GetVipRecordsReq) (*moe.GetVipRecordsResp, error) {
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 10
	}
	offset := (page - 1) * pageSize

	var orders []model.VipOrder
	var total int64
	if err := db.WithContext(ctx).Model(&model.VipOrder{}).Where("user_id = ?", in.GetUserId()).Count(&total).Error; err != nil {
		return nil, err
	}
	if err := db.WithContext(ctx).Preload("Plan").Where("user_id = ?", in.GetUserId()).
		Offset(int(offset)).Limit(int(pageSize)).Find(&orders).Error; err != nil {
		return nil, err
	}

	respRecords := make([]*moe.VipRecord, len(orders))
	for i, order := range orders {
		status := "inactive"
		if order.IsActive {
			status = "active"
		}
		startAt, endAt := "", ""
		if order.StartAt != nil {
			startAt = order.StartAt.Format("2006-01-02 15:04:05")
		}
		if order.EndAt != nil {
			endAt = order.EndAt.Format("2006-01-02 15:04:05")
		}
		respRecords[i] = &moe.VipRecord{
			Id:        strconv.Itoa(int(order.ID)),
			UserId:    in.GetUserId(),
			PlanId:    strconv.Itoa(int(order.PlanID)),
			PlanName:  order.Plan.Name,
			StartAt:   startAt,
			EndAt:     endAt,
			Status:    status,
			CreatedAt: order.CreatedAt.Format("2006-01-02 15:04:05"),
		}
	}
	return &moe.GetVipRecordsResp{Records: respRecords, Total: int32(total)}, nil
}

// GetUserActiveVipRecord 当前有效 VIP 订单。
func GetUserActiveVipRecord(ctx context.Context, db *gorm.DB, in *moe.GetUserActiveVipRecordReq) (*moe.GetUserActiveVipRecordResp, error) {
	var order model.VipOrder
	err := db.WithContext(ctx).Where("user_id = ? AND is_active = ? AND end_at > ? AND status = ?",
		in.GetUserId(), true, time.Now(), "paid").First(&order).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNoActiveVip
		}
		return nil, err
	}
	var plan model.VipPlan
	_ = db.WithContext(ctx).First(&plan, order.PlanID).Error
	return &moe.GetUserActiveVipRecordResp{
		Record: &moe.VipRecord{
			Id:        strconv.Itoa(int(order.ID)),
			UserId:    strconv.Itoa(int(order.UserID)),
			PlanId:    strconv.Itoa(int(order.PlanID)),
			PlanName:  plan.Name,
			StartAt:   order.StartAt.Format("2006-01-02 15:04:05"),
			EndAt:     order.EndAt.Format("2006-01-02 15:04:05"),
			Status:    "active",
			CreatedAt: order.CreatedAt.Format("2006-01-02 15:04:05"),
		},
	}, nil
}
