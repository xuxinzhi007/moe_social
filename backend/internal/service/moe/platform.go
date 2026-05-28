package moeadmin

import (
	"context"
	"errors"

	moebiz "backend/internal/biz/moe"
)

// ToolExecutor Moe 工具执行后端（MoeGW 或进程内 AdminService）。
type ToolExecutor interface {
	ExecuteTool(ctx context.Context, in moebiz.ExecuteToolInput) (moebiz.ExecuteToolResult, error)
}

// PlatformApp 平台侧 Moe 工具应用服务。
type PlatformApp struct {
	exec ToolExecutor
}

// NewPlatform 构造 PlatformApp。
func NewPlatform(exec ToolExecutor) *PlatformApp {
	return &PlatformApp{exec: exec}
}

// ToolsSchema 返回工具 schema。
func (p *PlatformApp) ToolsSchema() moebiz.ToolsSchemaResult {
	return moebiz.ToolsSchema()
}

// ExecuteTool 执行 Moe 工具。
func (p *PlatformApp) ExecuteTool(ctx context.Context, in moebiz.ExecuteToolInput) (moebiz.ExecuteToolResult, error) {
	if p == nil || p.exec == nil {
		return moebiz.ExecuteToolResult{}, errors.New("moe platform unavailable")
	}
	return p.exec.ExecuteTool(ctx, in)
}
