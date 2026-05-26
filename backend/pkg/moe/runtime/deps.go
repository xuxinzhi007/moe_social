package runtime

import (
	"backend/pkg/llminference"
	"backend/pkg/moe/port"

	"gorm.io/gorm"
)

// Deps Agent 运行时依赖。
type Deps struct {
	DB        *gorm.DB
	RPC       port.SuperPort
	Inference llminference.Config
}

// SmartOpts 智能发送调度参数（可由 config.yaml 覆盖）。
type SmartOpts struct {
	RetryIntervalMinutes int
	MinIntervalHours     int
}

// DefaultSmartOpts 默认智能发送间隔。
func DefaultSmartOpts() SmartOpts {
	return SmartOpts{
		RetryIntervalMinutes: 30,
		MinIntervalHours:     2,
	}
}
