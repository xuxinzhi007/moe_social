package moebiz

import (
	"context"
	"strings"

	"backend/pkg/moe/runtime"
)

// RunAgentOnce 执行一次 Bot 试跑回合。
func RunAgentOnce(ctx context.Context, deps runtime.Deps, agentKey string) (runtime.RunOnceResult, error) {
	return runtime.RunOnce(ctx, deps, strings.TrimSpace(agentKey))
}
