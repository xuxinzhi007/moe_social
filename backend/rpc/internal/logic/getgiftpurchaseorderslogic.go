package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type GetGiftPurchaseOrdersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetGiftPurchaseOrdersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGiftPurchaseOrdersLogic {
	return &GetGiftPurchaseOrdersLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetGiftPurchaseOrdersLogic) GetGiftPurchaseOrders(in *super.GetGiftPurchaseOrdersReq) (*super.GetGiftPurchaseOrdersResp, error) {
	uid, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil {
		return nil, errorx.New(400, "无效的用户ID")
	}

	var u model.User
	if err := l.svcCtx.DB.First(&u, uid).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, errorx.New(404, "用户不存在")
		}
		return nil, errorx.Internal("查找用户失败")
	}

	page := in.Page
	if page <= 0 {
		page = 1
	}
	pageSize := in.PageSize
	if pageSize <= 0 {
		pageSize = 10
	}
	offset := (page - 1) * pageSize

	var total int64
	if err := l.svcCtx.DB.Model(&model.GiftPurchaseOrder{}).Where("user_id = ?", uid).Count(&total).Error; err != nil {
		return nil, errorx.Internal("查询订单总数失败")
	}

	var rows []model.GiftPurchaseOrder
	if err := l.svcCtx.DB.Where("user_id = ?", uid).
		Order("created_at DESC").
		Offset(int(offset)).
		Limit(int(pageSize)).
		Find(&rows).Error; err != nil {
		return nil, errorx.Internal("查询订单列表失败")
	}

	out := make([]*super.GiftPurchaseOrder, 0, len(rows))
	for _, o := range rows {
		out = append(out, &super.GiftPurchaseOrder{
			Id:          strconv.FormatUint(uint64(o.ID), 10),
			UserId:      in.GetUserId(),
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

	return &super.GetGiftPurchaseOrdersResp{
		Orders: out,
		Total:  int32(total),
	}, nil
}
