package utils

import (
	"backend/model"
	"errors"

	"gorm.io/gorm"
)

// SeedDefaultGifts 同步全量礼物到数据库（与 App 端展示清单一致），按名称 upsert。
// 由 postMigrate 在 RPC 带 -migrate 启动时执行；改本文件后请再跑一次 go run super.go -migrate。
func SeedDefaultGifts(db *gorm.DB) {
	seeds := []model.Gift{
		{Name: "爱心", Price: 1, Icon: "❤️", Description: "传递温暖的爱意"},
		{Name: "鲜花", Price: 2, Icon: "🌹", Description: "美丽的玫瑰花"},
		{Name: "点赞", Price: 1, Icon: "👍", Description: "给你一个大大的赞"},
		{Name: "掌声", Price: 2, Icon: "👏", Description: "为你精彩的分享鼓掌"},
		{Name: "拥抱", Price: 3, Icon: "🤗", Description: "给你一个温暖的拥抱"},
		{Name: "咖啡", Price: 5, Icon: "☕", Description: "香浓的咖啡为你提神"},
		{Name: "蛋糕", Price: 10, Icon: "🎂", Description: "甜蜜的生日蛋糕"},
		{Name: "冰淇淋", Price: 6, Icon: "🍦", Description: "清爽的冰淇淋"},
		{Name: "香槟", Price: 15, Icon: "🍾", Description: "庆祝时刻的香槟"},
		{Name: "钻石", Price: 50, Icon: "💎", Description: "闪闪发光的钻石"},
		{Name: "皇冠", Price: 100, Icon: "👑", Description: "尊贵的皇冠"},
		{Name: "火箭", Price: 200, Icon: "🚀", Description: "让你的内容飞向太空"},
		{Name: "彩虹", Price: 30, Icon: "🌈", Description: "七彩斑斓的彩虹"},
		{Name: "烟花", Price: 25, Icon: "🎆", Description: "绚烂的烟花表演"},
		{Name: "独角兽", Price: 67, Icon: "🦄", Description: "神奇的独角兽"},
		// 与早期种子兼容：名称不同则保留为另一条；同名则更新
		{Name: "奶茶", Price: 8, Icon: "🧋", Description: "请你喝一杯"},
		{Name: "小蛋糕", Price: 12, Icon: "🍰", Description: "甜蜜加分"},
		{Name: "星星灯", Price: 20, Icon: "✨", Description: "点亮心情"},
	}
	for _, s := range seeds {
		var row model.Gift
		err := db.Where("name = ?", s.Name).First(&row).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			_ = db.Create(&s).Error
			continue
		}
		if err != nil {
			continue
		}
		if row.Price == s.Price && row.Icon == s.Icon && row.Description == s.Description {
			continue
		}
		_ = db.Model(&row).Updates(map[string]interface{}{
			"price":       s.Price,
			"icon":        s.Icon,
			"description": s.Description,
		}).Error
	}
}
