package model

import "time"

// GormSchemaVersion 记录每张业务表的 model 结构指纹，用于跳过未变更表的 AutoMigrate 对账。
type GormSchemaVersion struct {
	TableName string    `gorm:"size:64;primaryKey" json:"table_name"`
	ModelHash string    `gorm:"size:64;not null" json:"model_hash"`
	UpdatedAt time.Time `json:"updated_at"`
}
