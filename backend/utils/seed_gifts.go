package utils

import (
	"backend/model"

	"gorm.io/gorm"
)

// SeedDefaultGifts 在礼物表为空时写入基础商品，便于「心意」购买与赠送闭环。
func SeedDefaultGifts(db *gorm.DB) {
	var n int64
	if err := db.Model(&model.Gift{}).Count(&n).Error; err != nil || n > 0 {
		return
	}
	seeds := []model.Gift{
		{Name: "爱心", Price: 1, Icon: "❤️", Description: "传递温暖心意"},
		{Name: "鲜花", Price: 5, Icon: "🌹", Description: "一束玫瑰"},
		{Name: "奶茶", Price: 8, Icon: "🧋", Description: "请你喝一杯"},
		{Name: "小蛋糕", Price: 12, Icon: "🍰", Description: "甜蜜加分"},
		{Name: "星星灯", Price: 20, Icon: "✨", Description: "点亮心情"},
	}
	_ = db.Create(&seeds).Error
}
