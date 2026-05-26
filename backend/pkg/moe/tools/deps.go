package tools

import (
	"backend/pkg/llminference"
	"backend/pkg/moe/port"

	"gorm.io/gorm"
)

// Deps 工具执行依赖。
type Deps struct {
	DB        *gorm.DB
	RPC       port.SuperPort
	Inference llminference.Config
}
