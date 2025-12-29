package logic

import (
	"context"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
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
	// 验证用户是否存在
	var user model.User
	userResult := l.svcCtx.DB.First(&user, in.UserId)
	if userResult.Error != nil {
		l.Error("查找用户失败: ", userResult.Error)
		return nil, errorx.NotFound("用户不存在")
	}

	// 验证套餐是否存在
	var plan model.VipPlan
	planResult := l.svcCtx.DB.First(&plan, in.PlanId)
	if planResult.Error != nil {
		l.Error("查找VIP套餐失败: ", planResult.Error)
		return nil, errorx.NotFound("VIP套餐不存在")
	}

	// 生成订单号（简化版，使用时间戳+随机数）
	orderNo := "ORD" + time.Now().Format("20060102150405") + in.UserId

	// 创建订单
	order := model.VipOrder{
		UserID:    user.ID,
		PlanID:    plan.ID,
		OrderNo:   orderNo,
		Amount:    plan.Price,
		Status:    "pending", // 初始状态为待支付
		PayMethod: "",
	}

	createResult := l.svcCtx.DB.Create(&order)
	if createResult.Error != nil {
		l.Error("创建订单失败: ", createResult.Error)
		return nil, errorx.Internal("创建订单失败")
	}

	// 构建响应
	return &super.CreateVipOrderResp{
		Order: &super.VipOrder{
			Id:        string(rune(order.ID)),
			UserId:    in.UserId,
			PlanId:    in.PlanId,
			PlanName:  plan.Name,
			Amount:    float32(order.Amount),
			Status:    order.Status,
			CreatedAt: order.CreatedAt.Format("2006-01-02 15:04:05"),
		},
	}, nil
}
