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

type AdminListGiftPurchaseOrdersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListGiftPurchaseOrdersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListGiftPurchaseOrdersLogic {
	return &AdminListGiftPurchaseOrdersLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminListGiftPurchaseOrdersLogic) AdminListGiftPurchaseOrders(in *super.AdminListGiftPurchaseOrdersReq) (*super.AdminListGiftPurchaseOrdersResp, error) {
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

	q := l.svcCtx.DB.Model(&model.GiftPurchaseOrder{})
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
		l.Errorf("[admin] count gift purchase orders: %v", err)
		return nil, errorx.Internal("查询礼物订单失败")
	}

	var rows []model.GiftPurchaseOrder
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[admin] list gift purchase orders: %v", err)
		return nil, errorx.Internal("查询礼物订单失败")
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

	return &super.AdminListGiftPurchaseOrdersResp{
		Orders: out,
		Total:  int32(total),
	}, nil
}
