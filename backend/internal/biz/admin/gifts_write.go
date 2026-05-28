package adminbiz

import (
	"context"
	"errors"
	"strings"

	giftbiz "backend/internal/biz/gift"
	"backend/model"
	"backend/rpc/pb/moe"
	"backend/utils"

	"gorm.io/gorm"
)

var (
	ErrEmptyGiftName     = errors.New("empty gift name")
	ErrNegativePrice     = errors.New("negative gift price")
	ErrEmptyCategory     = errors.New("empty gift category")
	ErrDuplicateGiftName = errors.New("duplicate gift name")
)

// UpdateGiftInput Admin 礼物部分更新。
type UpdateGiftInput struct {
	GiftIDRaw         string
	Name              string
	Price             int32
	Icon              string
	Description       string
	Category          string
	SortOrder         int32
	UpdateName        bool
	UpdatePrice       bool
	UpdateIcon        bool
	UpdateDescription bool
	UpdateCategory    bool
	UpdateSortOrder   bool
}

// CreateGift 创建礼物。
func CreateGift(ctx context.Context, db *gorm.DB, in *moe.AdminCreateGiftReq) (*moe.Gift, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	name := strings.TrimSpace(in.GetName())
	if name == "" {
		return nil, ErrEmptyGiftName
	}
	if in.GetPrice() < 0 {
		return nil, ErrNegativePrice
	}
	category := strings.TrimSpace(in.GetCategory())
	if category == "" {
		category = "special"
	}
	var dup model.Gift
	if err := db.WithContext(ctx).Where("name = ?", name).First(&dup).Error; err == nil {
		return nil, ErrDuplicateGiftName
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	gift := model.Gift{
		Name:        name,
		Price:       int(in.GetPrice()),
		Icon:        strings.TrimSpace(in.GetIcon()),
		Description: strings.TrimSpace(in.GetDescription()),
		Category:    category,
		SortOrder:   int(in.GetSortOrder()),
	}
	if err := db.WithContext(ctx).Create(&gift).Error; err != nil {
		return nil, err
	}
	return giftbiz.GiftToProto(gift, 0), nil
}

// UpdateGift 更新礼物。
func UpdateGift(ctx context.Context, db *gorm.DB, in UpdateGiftInput) (*moe.Gift, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	giftID, err := giftbiz.ParseGiftID(in.GiftIDRaw)
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
	if in.UpdateName {
		name := strings.TrimSpace(in.Name)
		if name == "" {
			return nil, ErrEmptyGiftName
		}
		var dup model.Gift
		if err := db.WithContext(ctx).Where("name = ? AND id <> ?", name, gift.ID).First(&dup).Error; err == nil {
			return nil, ErrDuplicateGiftName
		} else if !errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, err
		}
		gift.Name = name
	}
	if in.UpdatePrice {
		if in.Price < 0 {
			return nil, ErrNegativePrice
		}
		gift.Price = int(in.Price)
	}
	if in.UpdateIcon {
		gift.Icon = strings.TrimSpace(in.Icon)
	}
	if in.UpdateDescription {
		gift.Description = strings.TrimSpace(in.Description)
	}
	if in.UpdateCategory {
		cat := strings.TrimSpace(in.Category)
		if cat == "" {
			return nil, ErrEmptyCategory
		}
		gift.Category = cat
	}
	if in.UpdateSortOrder {
		gift.SortOrder = int(in.SortOrder)
	}
	if err := db.WithContext(ctx).Save(&gift).Error; err != nil {
		return nil, err
	}
	return giftbiz.GiftToProto(gift, 0), nil
}

// DeleteGift 删除礼物。
func DeleteGift(ctx context.Context, db *gorm.DB, giftIDRaw string) error {
	if db == nil {
		return gorm.ErrInvalidDB
	}
	giftID, err := giftbiz.ParseGiftID(giftIDRaw)
	if err != nil {
		return err
	}
	res := db.WithContext(ctx).Delete(&model.Gift{}, giftID)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrGiftNotFound
	}
	return nil
}

// BootstrapGifts 空表时写入默认礼物。
func BootstrapGifts(ctx context.Context, db *gorm.DB) (int32, error) {
	if db == nil {
		return 0, gorm.ErrInvalidDB
	}
	var count int64
	if err := db.WithContext(ctx).Model(&model.Gift{}).Count(&count).Error; err != nil {
		return 0, err
	}
	if count > 0 {
		return 0, nil
	}
	utils.SeedDefaultGifts(db)
	if err := db.WithContext(ctx).Model(&model.Gift{}).Count(&count).Error; err != nil {
		return 0, err
	}
	return int32(count), nil
}

// DeduplicateGiftsByName 合并同名礼物：保留最小 ID，迁移引用后删除重复项。
func DeduplicateGiftsByName(ctx context.Context, db *gorm.DB) (int32, error) {
	if db == nil {
		return 0, gorm.ErrInvalidDB
	}
	var gifts []model.Gift
	if err := db.WithContext(ctx).Order("id ASC").Find(&gifts).Error; err != nil {
		return 0, err
	}
	canonical := map[string]uint{}
	var removed int32
	err := db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		for _, gift := range gifts {
			name := strings.TrimSpace(gift.Name)
			if name == "" {
				continue
			}
			if keepID, ok := canonical[name]; ok {
				if err := reassignGiftReferences(ctx, tx, gift.ID, keepID); err != nil {
					return err
				}
				if err := tx.Delete(&model.Gift{}, gift.ID).Error; err != nil {
					return err
				}
				removed++
				continue
			}
			canonical[name] = gift.ID
		}
		return nil
	})
	if err != nil {
		return 0, err
	}
	return removed, nil
}

func reassignGiftReferences(ctx context.Context, tx *gorm.DB, fromID, toID uint) error {
	if fromID == toID {
		return nil
	}
	if err := tx.WithContext(ctx).Model(&model.GiftRecord{}).
		Where("gift_id = ?", fromID).
		Update("gift_id", toID).Error; err != nil {
		return err
	}
	if err := tx.WithContext(ctx).Model(&model.GiftPurchaseOrder{}).
		Where("gift_id = ?", fromID).
		Update("gift_id", toID).Error; err != nil {
		return err
	}
	var stocks []model.UserGiftStock
	if err := tx.WithContext(ctx).Where("gift_id = ?", fromID).Find(&stocks).Error; err != nil {
		return err
	}
	for _, stock := range stocks {
		var existing model.UserGiftStock
		err := tx.WithContext(ctx).
			Where("user_id = ? AND gift_id = ?", stock.UserID, toID).
			First(&existing).Error
		if err == nil {
			if err := tx.WithContext(ctx).Model(&existing).
				Update("quantity", existing.Quantity+stock.Quantity).Error; err != nil {
				return err
			}
			if err := tx.WithContext(ctx).Delete(&stock).Error; err != nil {
				return err
			}
			continue
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		if err := tx.WithContext(ctx).Model(&stock).Update("gift_id", toID).Error; err != nil {
			return err
		}
	}
	return nil
}
