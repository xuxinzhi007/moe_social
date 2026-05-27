package model

import "time"

// TagDictionaryEntry Bot 策略标签字典（禁止/偏好），与 topic_tags 话题标签分开管理。
type TagDictionaryEntry struct {
	ID        uint      `gorm:"primarykey" json:"id"`
	Category  string    `gorm:"size:32;not null;uniqueIndex:idx_tag_dict_cat_tag" json:"category"`
	Tag       string    `gorm:"size:128;not null;uniqueIndex:idx_tag_dict_cat_tag" json:"tag"`
	Label     string    `gorm:"size:256" json:"label"`
	Note      string    `gorm:"size:512" json:"note"`
	SortOrder int       `gorm:"default:0" json:"sort_order"`
	Enabled   bool      `gorm:"default:true" json:"enabled"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (TagDictionaryEntry) TableName() string {
	return "tag_dictionary_entries"
}
