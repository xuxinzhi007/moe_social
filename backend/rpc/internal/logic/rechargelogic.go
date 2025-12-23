package logic

import (
	"context"
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

	// 3. 查找用户
	var user model.User
	if err := l.svcCtx.DB.First(&user, uint(userID)).Error; err != nil {
		return nil, errorx.New(404, "用户不存在")
	}

	// 4. 更新用户余额
	amount := float64(in.Amount)
	newBalance := user.Balance + amount
	if err := l.svcCtx.DB.Model(&user).Update("balance", newBalance).Error; err != nil {
		l.Error("更新用户余额失败: ", err)
		return nil, errorx.New(500, "充值失败，请稍后重试")
	}

	// 5. 创建交易记录
	transaction := model.Transaction{
		UserID:      uint(userID),
		Amount:      amount,
		Type:        "recharge",
		Status:      "success",
		Description: in.Description,
	}
	if err := l.svcCtx.DB.Create(&transaction).Error; err != nil {
		l.Error("创建交易记录失败: ", err)
		// 这里不返回错误，因为余额已经更新成功
	}

	// 6. 返回响应
	return &rpc.RechargeResp{
		Message:    "充值成功",
		NewBalance: float32(newBalance),
	}, nil
}
