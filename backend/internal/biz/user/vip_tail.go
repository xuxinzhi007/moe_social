package userbiz

import (
	"context"
	"errors"
	"strconv"
	"time"

	vipv1 "backend/api/vip/v1"
	"backend/model"
	"backend/pkg/achievement"

	"gorm.io/gorm"
)

// CreateVipOrder 钱包购买 VIP 套餐。
func CreateVipOrder(ctx context.Context, store UserStore, in *vipv1.CreateVipOrderReq) (*vipv1.CreateVipOrderResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	var order model.VipOrder
	var paidUserID uint

	tx, err := store.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback() }()

	user, err := tx.GetUserForUpdate(in.GetUserId())
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	plan, err := tx.GetVipPlan(in.GetPlanId())
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrVipPlanNotFound
		}
		return nil, err
	}
	if user.Balance < plan.Price {
		return nil, ErrInsufficientBalance
	}

	orderNo := "ORD" + strconv.FormatInt(time.Now().UnixNano(), 10)
	now := time.Now()
	vipEnd := now.AddDate(0, 0, plan.Duration)

	if err := tx.DeactivateVipOrders(user.ID); err != nil {
		return nil, err
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
	if err := tx.CreateVipOrder(&order); err != nil {
		return nil, err
	}

	newBalance := user.Balance - plan.Price
	if err := tx.UpdateUserBalance(user.ID, newBalance); err != nil {
		return nil, err
	}

	transaction := model.Transaction{
		UserID:      user.ID,
		Amount:      plan.Price,
		Type:        "consume",
		Status:      "success",
		Description: "购买VIP套餐：" + plan.Name,
	}
	if err := tx.CreateTransaction(&transaction); err != nil {
		return nil, err
	}

	user.IsVip = true
	user.VipStartAt = &now
	user.VipEndAt = &vipEnd
	if err := tx.SaveUser(&user); err != nil {
		return nil, err
	}
	order.Plan = plan
	paidUserID = user.ID

	if err := tx.Commit(); err != nil {
		return nil, err
	}

	var achUnlocks []achievement.UnlockResult
	if paidUserID > 0 {
		unlocks, achErr := achievement.ApplyEventAfterCommit(store.Raw(), paidUserID, achievement.Event{Type: achievement.EventVipActivated})
		if achErr == nil {
			achUnlocks = unlocks
		}
	}

	return &vipv1.CreateVipOrderResp{
		NewAchievements: achievementUnlocksToVipV1(achUnlocks),
		Order: &vipv1.VipOrder{
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
func UpdateUserVip(ctx context.Context, store UserStore, in *vipv1.UpdateUserVipReq) (*vipv1.UpdateUserVipResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserIDString(in.GetUserId())
	if err != nil {
		return nil, err
	}
	user, err := store.GetUserByID(ctx, userID)
	if err != nil {
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
		_ = store.DeactivateVipOrders(ctx, user.ID)
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
		if err := store.CreateVipOrderRecord(ctx, &vipOrder); err != nil {
			return nil, err
		}
		user.IsVip = true
		user.VipStartAt = &vipStart
		user.VipEndAt = &vipExpires
	} else {
		user.IsVip = false
		user.VipStartAt = nil
		user.VipEndAt = nil
		_ = store.DeactivateVipOrders(ctx, user.ID)
	}

	if err := store.SaveUser(ctx, &user); err != nil {
		return nil, err
	}
	return &vipv1.UpdateUserVipResp{User: ModelToVipUserV1(&user)}, nil
}

// SyncUserVipStatus 按过期时间同步 VIP 标记。
func SyncUserVipStatus(ctx context.Context, store UserStore, in *vipv1.SyncUserVipStatusReq) (*vipv1.SyncUserVipStatusResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserIDString(in.GetUserId())
	if err != nil {
		return nil, err
	}
	user, err := store.GetUserByID(ctx, userID)
	if err != nil {
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
			_ = store.SaveUser(ctx, &user)
		}
	}
	return &vipv1.SyncUserVipStatusResp{IsVip: isVip, ExpiresAt: vipEndAt}, nil
}

// UpdateAutoRenew 占位（模型暂无字段）。
func UpdateAutoRenew(ctx context.Context, store UserStore, in *vipv1.UpdateAutoRenewReq) (*vipv1.UpdateAutoRenewResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserIDString(in.GetUserId())
	if err != nil {
		return nil, err
	}
	if _, err := store.GetUserByID(ctx, userID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &vipv1.UpdateAutoRenewResp{}, nil
}

// GetVipRecords 分页 VIP 订单记录。
func GetVipRecords(ctx context.Context, store UserStore, in *vipv1.GetVipRecordsReq) (*vipv1.GetVipRecordsResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 10
	}
	offset := int((page - 1) * pageSize)

	total, err := store.CountVipOrdersByUserID(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	orders, err := store.ListVipOrdersByUserID(ctx, in.GetUserId(), offset, int(pageSize))
	if err != nil {
		return nil, err
	}

	respRecords := make([]*vipv1.VipRecord, len(orders))
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
		respRecords[i] = &vipv1.VipRecord{
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
	return &vipv1.GetVipRecordsResp{Records: respRecords, Total: int32(total)}, nil
}

// GetUserActiveVipRecord 当前有效 VIP 订单。
func GetUserActiveVipRecord(ctx context.Context, store UserStore, in *vipv1.GetUserActiveVipRecordReq) (*vipv1.GetUserActiveVipRecordResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	order, err := store.GetActiveVipOrder(ctx, in.GetUserId())
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNoActiveVip
		}
		return nil, err
	}
	plan, _ := store.GetVipPlan(ctx, order.PlanID)
	return &vipv1.GetUserActiveVipRecordResp{
		Record: &vipv1.VipRecord{
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

func achievementUnlocksToVipV1(unlocks []achievement.UnlockResult) []*vipv1.AchievementUnlock {
	if len(unlocks) == 0 {
		return nil
	}
	out := make([]*vipv1.AchievementUnlock, 0, len(unlocks))
	for _, u := range unlocks {
		out = append(out, &vipv1.AchievementUnlock{
			BadgeId:    u.BadgeID,
			Name:       u.Name,
			ExpGranted: int32(u.ExpGranted),
			LevelUp:    u.LevelUp,
			NewLevel:   int32(u.NewLevel),
		})
	}
	return out
}
