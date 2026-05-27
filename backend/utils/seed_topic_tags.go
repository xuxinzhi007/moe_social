package utils

import (
	"errors"

	"backend/model"

	"gorm.io/gorm"
)

type topicTagSeed struct {
	Name  string
	Color string
}

// defaultTopicTagSeeds 与 Flutter TopicTag.officialTags 对齐。
var defaultTopicTagSeeds = []topicTagSeed{
	{Name: "日常生活", Color: "#42A5F5"},
	{Name: "心情随笔", Color: "#AB47BC"},
	{Name: "美食分享", Color: "#FF7043"},
	{Name: "旅行记录", Color: "#66BB6A"},
	{Name: "工作日志", Color: "#78909C"},
	{Name: "学习笔记", Color: "#26C6DA"},
}

// SeedDefaultTopicTags 按名称 upsert 官方话题标签。
func SeedDefaultTopicTags(db *gorm.DB) int32 {
	if db == nil {
		return 0
	}
	var created int32
	for _, s := range defaultTopicTagSeeds {
		var existing model.TopicTag
		err := db.Where("name = ?", s.Name).First(&existing).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			row := model.TopicTag{Name: s.Name, Color: s.Color}
			if db.Create(&row).Error == nil {
				created++
			}
			continue
		}
		if err != nil {
			continue
		}
		if existing.Color != s.Color {
			_ = db.Model(&existing).Update("color", s.Color).Error
		}
	}
	return created
}
