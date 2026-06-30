package utils

import (
	"backend/model"
	"errors"

	"gorm.io/gorm"
)

// giftSeed 礼物目录种子（唯一事实来源；改后执行 make db-migrate）
type giftSeed struct {
	Name        string
	Price       int
	Icon        string
	Description string
	Category    string
	SortOrder   int
}

// defaultGiftSeeds 全量礼物目录，按 sort_order 展示
var defaultGiftSeeds = []giftSeed{
	{Name: "爱心", Price: 1, Icon: "❤️", Description: "传递温暖的爱意", Category: "emotion", SortOrder: 10},
	{Name: "点赞", Price: 1, Icon: "👍", Description: "给你一个大大的赞", Category: "emotion", SortOrder: 20},
	{Name: "鲜花", Price: 2, Icon: "🌹", Description: "美丽的玫瑰花", Category: "emotion", SortOrder: 30},
	{Name: "掌声", Price: 2, Icon: "👏", Description: "为你精彩的分享鼓掌", Category: "emotion", SortOrder: 40},
	{Name: "拥抱", Price: 3, Icon: "🤗", Description: "给你一个温暖的拥抱", Category: "emotion", SortOrder: 50},
	{Name: "咖啡", Price: 5, Icon: "☕", Description: "香浓的咖啡为你提神", Category: "food", SortOrder: 60},
	{Name: "冰淇淋", Price: 6, Icon: "🍦", Description: "清爽的冰淇淋", Category: "food", SortOrder: 70},
	{Name: "奶茶", Price: 8, Icon: "🧋", Description: "请你喝一杯", Category: "food", SortOrder: 80},
	{Name: "蛋糕", Price: 10, Icon: "🎂", Description: "甜蜜的生日蛋糕", Category: "food", SortOrder: 90},
	{Name: "小蛋糕", Price: 12, Icon: "🍰", Description: "甜蜜加分", Category: "food", SortOrder: 100},
	{Name: "香槟", Price: 15, Icon: "🍾", Description: "庆祝时刻的香槟", Category: "food", SortOrder: 110},
	{Name: "星星灯", Price: 20, Icon: "✨", Description: "点亮心情", Category: "special", SortOrder: 120},
	{Name: "烟花", Price: 25, Icon: "🎆", Description: "绚烂的烟花表演", Category: "special", SortOrder: 130},
	{Name: "彩虹", Price: 30, Icon: "🌈", Description: "七彩斑斓的彩虹", Category: "special", SortOrder: 140},
	{Name: "钻石", Price: 50, Icon: "💎", Description: "闪闪发光的钻石", Category: "luxury", SortOrder: 150},
	{Name: "独角兽", Price: 67, Icon: "🦄", Description: "神奇的独角兽", Category: "special", SortOrder: 160},
	{Name: "皇冠", Price: 100, Icon: "👑", Description: "尊贵的皇冠", Category: "luxury", SortOrder: 170},
	{Name: "火箭", Price: 200, Icon: "🚀", Description: "让你的内容飞向太空", Category: "luxury", SortOrder: 180},
}

// SeedDefaultGifts 同步全量礼物到数据库，按名称 upsert。
// 由 Admin「导入默认礼物」在表为空时调用；迁移不再自动执行。
func SeedDefaultGifts(db *gorm.DB) {
	for _, s := range defaultGiftSeeds {
		row := model.Gift{
			Name:        s.Name,
			Price:       s.Price,
			Icon:        s.Icon,
			Description: s.Description,
			Category:    s.Category,
			SortOrder:   s.SortOrder,
		}
		var existing model.Gift
		err := db.Where("name = ?", s.Name).First(&existing).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			_ = db.Create(&row).Error
			continue
		}
		if err != nil {
			continue
		}
		if existing.Price == s.Price && existing.Icon == s.Icon &&
			existing.Description == s.Description && existing.Category == s.Category &&
			existing.SortOrder == s.SortOrder {
			continue
		}
		_ = db.Model(&existing).Updates(map[string]interface{}{
			"price":       s.Price,
			"icon":        s.Icon,
			"description": s.Description,
			"category":    s.Category,
			"sort_order":  s.SortOrder,
		}).Error
	}
}
