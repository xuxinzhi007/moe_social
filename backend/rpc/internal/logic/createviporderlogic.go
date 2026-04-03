package logic

import (
	"context"
	"strconv"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type CreateVipOrderLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreateVipOrderLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateVipOrderLogic {
	return &CreateVipOrderLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 用户相关服务
func (l *CreateVipOrderLogic) CreateVipOrder(in *super.CreateVipOrderReq) (*super.CreateVipOrderResp, error) {
	var order model.VipOrder
	err := l.svcCtx.DB.Transaction(func(tx *gorm.DB) error {
		// 验证用户是否存在并加锁
		var user model.User
		if err := tx.Set("gorm:query_option", "FOR UPDATE").First(&user, in.UserId).Error; err != nil {
			l.Error("查找用户失败: ", err)
			return errorx.NotFound("用户不存在")
		}

		// 验证套餐是否存在
		var plan model.VipPlan
		if err := tx.First(&plan, in.PlanId).Error; err != nil {
			l.Error("查找VIP套餐失败: ", err)
			return errorx.NotFound("VIP套餐不存在")
		}

		// 检查钱包余额
		if user.Balance < plan.Price {
			return errorx.New(400, "余额不足，请先充值")
		}

		// 生成订单号
		orderNo := "ORD" + time.Now().Format("20060102150405") + in.UserId
		now := time.Now()
		vipEnd := now.AddDate(0, 0, plan.Duration)

		// 老订单全部失效
		if err := tx.Model(&model.VipOrder{}).
			Where("user_id = ?", user.ID).
			Update("is_active", false).Error; err != nil {
			return err
		}

		// 创建并直接支付成功
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
			l.Error("创建订单失败: ", err)
			return errorx.Internal("创建订单失败")
		}

		// 扣减钱包余额
		newBalance := user.Balance - plan.Price
		if err := tx.Model(&user).UpdateColumn("balance", newBalance).Error; err != nil {
			l.Error("扣减用户余额失败: ", err)
			return errorx.Internal("扣减用户余额失败")
		}

		// 写入交易记录
		transaction := model.Transaction{
			UserID:      user.ID,
			Amount:      plan.Price,
			Type:        "consume",
			Status:      "success",
			Description: "购买VIP套餐：" + plan.Name,
		}
		if err := tx.Create(&transaction).Error; err != nil {
			l.Error("创建交易记录失败: ", err)
			return errorx.Internal("创建交易记录失败")
		}

		// 更新用户VIP状态
		user.IsVip = true
		user.VipStartAt = &now
		user.VipEndAt = &vipEnd
		if err := tx.Save(&user).Error; err != nil {
			l.Error("更新用户VIP状态失败: ", err)
			return errorx.Internal("更新用户VIP状态失败")
		}

		// 预加载套餐，供响应使用
		order.Plan = plan
		return nil
	})
	if err != nil {
		return nil, err
	}

	return &super.CreateVipOrderResp{
		Order: &super.VipOrder{
			Id:        strconv.FormatUint(uint64(order.ID), 10),
			UserId:    in.UserId,
			PlanId:    strconv.FormatUint(uint64(order.PlanID), 10),
			PlanName:  order.Plan.Name,
			Amount:    float32(order.Amount),
			Status:    order.Status,
			CreatedAt: order.CreatedAt.Format("2006-01-02 15:04:05"),
			PaidAt:    order.UpdatedAt.Format("2006-01-02 15:04:05"),
		},
	}, nil
}
