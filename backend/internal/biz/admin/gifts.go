package adminbiz

import (
	"context"
	"errors"
	"strings"

	giftbiz "backend/internal/biz/gift"
	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// ErrGiftNotFound Admin 礼物不存在。
var ErrGiftNotFound = errors.New("gift not found")

// GiftPage Admin 礼物列表筛选。
type GiftPage struct {
	Page     int32
	PageSize int32
	Keyword  string
	Category string
}

// ListGifts Admin 礼物列表（keyword/category 筛选）。
func ListGifts(ctx context.Context, db *gorm.DB, in GiftPage) ([]*super.Gift, int32, error) {
	if db == nil {
		return nil, 0, gorm.ErrInvalidDB
	}
	page := in.Page
	if page <= 0 {
		page = 1
	}
	pageSize := in.PageSize
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}
	q := db.WithContext(ctx).Model(&model.Gift{})
	if kw := strings.TrimSpace(in.Keyword); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("name LIKE ? OR description LIKE ?", like, like)
	}
	if cat := strings.TrimSpace(in.Category); cat != "" {
		q = q.Where("category = ?", cat)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var rows []model.Gift
	offset := int((page - 1) * pageSize)
	if err := q.Order("sort_order ASC, id ASC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, 0, err
	}
	gifts := make([]*super.Gift, len(rows))
	for i := range rows {
		gifts[i] = giftbiz.GiftToProto(rows[i], 0)
	}
	return gifts, int32(total), nil
}

// GetGift Admin 礼物详情。
func GetGift(ctx context.Context, db *gorm.DB, giftIDRaw string) (*super.Gift, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	giftID, err := giftbiz.ParseGiftID(giftIDRaw)
	if err != nil {
		return nil, err
	}
	var gift model.Gift
	if err := db.WithContext(ctx).First(&gift, giftID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrGiftNotFound
		}
		return nil, err
	}
	return giftbiz.GiftToProto(gift, 0), nil
}
