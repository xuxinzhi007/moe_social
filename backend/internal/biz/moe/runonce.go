package moebiz

import (
	"context"
	"strings"

	"backend/pkg/moe/runtime"
)

// RunAgentOnce 执行一次 Bot 试跑回合（走画布编排）。
func RunAgentOnce(ctx context.Context, deps runtime.Deps, agentKey string) (runtime.RunOnceResult, error) {
	return runtime.RunAgentForAgent(ctx, deps, strings.TrimSpace(agentKey), runtime.TriggerAdminTest)
}
