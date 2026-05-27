package moeadmin

import (
	"context"

	"backend/pkg/moe/brain"
	"backend/pkg/moe/port"
	"backend/pkg/moe/runtime"
	"backend/pkg/moe/tools"
)

// RuntimeDepsFactory 由 RPC 进程在启动时注入（避免 service 依赖 logic 产生循环引用）。
type RuntimeDepsFactory func(context.Context) runtime.Deps

// SuperPortFactory 由 RPC 进程在启动时注入。
type SuperPortFactory func(context.Context) port.SuperPort

// BrainDepsFactory brain.Deps 工厂。
type BrainDepsFactory func(context.Context) brain.Deps

// BrainRefineDepsFactory brain.RefineDeps 工厂。
type BrainRefineDepsFactory func(context.Context) brain.RefineDeps

// ToolsDepsFactory tools.Deps 工厂。
type ToolsDepsFactory func(context.Context) tools.Deps
