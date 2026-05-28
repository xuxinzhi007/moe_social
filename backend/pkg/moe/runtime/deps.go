package runtime

import (
	"context"

	"backend/pkg/llminference"
	"backend/pkg/moe/flowexec"
	"backend/pkg/moe/port"

	"gorm.io/gorm"
)

// PostingPlanResolver 按 agent 加载发帖编排（由 RPC/平台注入，避免 pkg 依赖 internal）。
type PostingPlanResolver func(ctx context.Context, db *gorm.DB, agentKey string) (flowexec.Plan, error)

// Deps Agent 运行时依赖。
type Deps struct {
	DB                 *gorm.DB
	RPC                port.SuperPort
	Inference          llminference.Config
	ResolvePostingPlan PostingPlanResolver
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
