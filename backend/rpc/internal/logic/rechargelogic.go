package logic

import (
	"context"
	"gorm.io/gorm"
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type RechargeLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewRechargeLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RechargeLogic {
	return &RechargeLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *RechargeLogic) Recharge(in *rpc.RechargeReq) (*rpc.RechargeResp, error) {
	// 1. 验证参数
	if in.UserId == "" {
		return nil, errorx.New(400, "用户ID不能为空")
	}
	if in.Amount <= 0 {
		return nil, errorx.New(400, "充值金额必须大于0")
	}

	// 2. 转换用户ID
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, errorx.New(400, "无效的用户ID")
	}

	var newBalance float64

	// 使用事务确保数据一致性
	err = l.svcCtx.DB.Transaction(func(tx *gorm.DB) error {
		// 3. 查找用户（加锁防止并发问题）
		var user model.User
		// 使用 Claused(clause.Locking{Strength: "UPDATE"}) 对选定的行进行加锁
		// 或者简单的 Set("gorm:query_option", "FOR UPDATE")
		if err := tx.Set("gorm:query_option", "FOR UPDATE").First(&user, uint(userID)).Error; err != nil {
			return errorx.New(404, "用户不存在")
		}

		// 4. 更新用户余额
		amount := float64(in.Amount)
		newBalance = user.Balance + amount

		// UpdateColumn 直接更新数据库字段，避免 GORM 默认 update 行为可能导致的问题
		if err := tx.Model(&user).UpdateColumn("balance", newBalance).Error; err != nil {
			l.Error("更新用户余额失败: ", err)
			return errorx.New(500, "充值失败，请稍后重试")
		}

		// 5. 创建交易记录
		transaction := model.Transaction{
			UserID:      uint(userID),
			Amount:      amount,
			Type:        "recharge",
			Status:      "success",
			Description: in.Description,
		}
		if err := tx.Create(&transaction).Error; err != nil {
			l.Error("创建交易记录失败: ", err)
			return errorx.New(500, "创建交易记录失败")
		}

		return nil
	})

	if err != nil {
		return nil, err
	}

	// 6. 返回响应
	return &rpc.RechargeResp{
		Message:    "充值成功",
		NewBalance: float32(newBalance),
	}, nil
}
