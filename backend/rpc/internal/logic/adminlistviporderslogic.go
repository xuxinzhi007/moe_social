package logic

import (
	"context"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListVipOrdersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListVipOrdersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListVipOrdersLogic {
	return &AdminListVipOrdersLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminListVipOrdersLogic) AdminListVipOrders(in *super.AdminListVipOrdersReq) (*super.AdminListVipOrdersResp, error) {
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

	q := l.svcCtx.DB.Model(&model.VipOrder{})
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
		l.Errorf("[admin] count vip orders: %v", err)
		return nil, errorx.Internal("查询 VIP 订单失败")
	}

	var rows []model.VipOrder
	offset := int((page - 1) * pageSize)
	if err := q.Preload("Plan").Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[admin] list vip orders: %v", err)
		return nil, errorx.Internal("查询 VIP 订单失败")
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

	return &super.AdminListVipOrdersResp{
		Orders: out,
		Total:  int32(total),
	}, nil
}
