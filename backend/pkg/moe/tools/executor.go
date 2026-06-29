package tools

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"backend/pkg/moe/core"
)

// Executor 统一工具执行器。
type Executor struct {
	deps Deps
}

// NewExecutor 构造执行器。
func NewExecutor(deps Deps) *Executor {
	return &Executor{deps: deps}
}

// Schema 返回工具定义。
func (e *Executor) Schema() []core.ToolSchema {
	return allSchemas()
}

// Execute 执行单个工具。
func (e *Executor) Execute(ctx context.Context, req core.ExecuteRequest) core.ExecuteResult {
	tool := strings.TrimSpace(req.Tool)
	if tool == "" {
		return fail("tool 不能为空")
	}
	if !req.Tier.AllowsTool(tool) {
		return fail(fmt.Sprintf("档位 %s 不允许工具 %s", req.Tier, tool))
	}

	switch tool {
	case "post_search":
		return e.execPostSearch(ctx, req)
	case "post_get":
		return e.execPostGet(ctx, req)
	case "post_create":
		return e.execPostCreate(ctx, req)
	case "brain_refine_episode":
		return e.execBrainRefineEpisode(ctx, req)
	case "brain_curate_memories":
		return e.execBrainCurateMemories(ctx, req)
	default:
		return fail("未知工具: " + tool)
	}
}

func fail(msg string) core.ExecuteResult {
	return core.ExecuteResult{OK: false, Error: msg}
}

func ok(payload any) core.ExecuteResult {
	b, err := json.Marshal(payload)
	if err != nil {
		return fail(err.Error())
	}
	return core.ExecuteResult{OK: true, Result: string(b)}
}

func parseArgs(raw string, dest any) error {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return fmt.Errorf("arguments 为空")
	}
	return json.Unmarshal([]byte(raw), dest)
}
