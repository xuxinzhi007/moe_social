package core

import "context"

// ExecuteRequest 工具执行入参（API / Runtime 共用）。
type ExecuteRequest struct {
	Tool           string
	ArgumentsJSON  string
	ActorUserID    uint
	BotUserID      uint
	AgentKey       string
	Tier           CapabilityTier
	IdempotencyKey string
}

// ExecuteResult 工具执行结果。
type ExecuteResult struct {
	OK     bool
	Result string
	Error  string
}

// Executor 工具执行器接口。
type Executor interface {
	Schema() []ToolSchema
	Execute(ctx context.Context, req ExecuteRequest) ExecuteResult
}

// ToolSchema OpenAI 兼容 tools 定义。
type ToolSchema struct {
	Name        string
	Description string
	Parameters  map[string]any
}
