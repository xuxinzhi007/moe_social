package logic

import (
	"context"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListGiftsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListGiftsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListGiftsLogic {
	return &AdminListGiftsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminListGiftsLogic) AdminListGifts(in *super.AdminListGiftsReq) (*super.AdminListGiftsResp, error) {
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

	q := l.svcCtx.DB.Model(&model.Gift{})
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("name LIKE ? OR description LIKE ?", like, like)
	}
	if cat := strings.TrimSpace(in.GetCategory()); cat != "" {
		q = q.Where("category = ?", cat)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		l.Errorf("[admin] count gifts: %v", err)
		return nil, errorx.Internal("查询礼物失败")
	}

	var rows []model.Gift
	offset := int((page - 1) * pageSize)
	if err := q.Order("sort_order ASC, id ASC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[admin] list gifts: %v", err)
		return nil, errorx.Internal("查询礼物失败")
	}

	gifts := make([]*super.Gift, len(rows))
	for i := range rows {
		gifts[i] = giftModelToProto(rows[i])
	}

	return &super.AdminListGiftsResp{
		Gifts: gifts,
		Total: int32(total),
	}, nil
}
