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
)

type GetUserActiveVipRecordLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserActiveVipRecordLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserActiveVipRecordLogic {
	return &GetUserActiveVipRecordLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserActiveVipRecordLogic) GetUserActiveVipRecord(in *super.GetUserActiveVipRecordReq) (*super.GetUserActiveVipRecordResp, error) {
	// 1. 查找用户当前激活的VIP订单
	var order model.VipOrder
	result := l.svcCtx.DB.Where("user_id = ? AND is_active = ? AND end_at > ? AND status = ?", in.UserId, true, time.Now(), "paid").First(&order)
	if result.Error != nil {
		l.Error("查找用户活跃VIP订单失败: ", result.Error)
		return nil, errorx.NotFound("用户没有活跃的VIP记录")
	}

	// 2. 查找关联的VIP套餐信息
	var plan model.VipPlan
	l.svcCtx.DB.First(&plan, order.PlanID)

	// 3. 构建响应
	return &super.GetUserActiveVipRecordResp{
		Record: &super.VipRecord{
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
