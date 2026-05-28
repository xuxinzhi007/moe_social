package moebiz

import (
	"context"
	"strings"

	"backend/pkg/moe/runtime"
)

// RunOnceStartResult 异步试跑启动结果。
type RunOnceStartResult struct {
	Accepted       bool
	AlreadyRunning bool
}

// TryStartRunAgentOnce 登记并返回是否可启动异步试跑（调用方在 goroutine 内执行 RunAgentOnce 且必须 defer End）。
func TryStartRunAgentOnce(agentKey string) RunOnceStartResult {
	key := strings.TrimSpace(agentKey)
	if key == "" {
		return RunOnceStartResult{}
	}
	if _, ok := runtime.LiveRuns.TryBegin(key); !ok {
		return RunOnceStartResult{AlreadyRunning: true}
	}
	return RunOnceStartResult{Accepted: true}
}

// EndRunAgentOnce 结束试跑登记（与 TryStartRunAgentOnce 配对）。
func EndRunAgentOnce(agentKey string) {
	runtime.LiveRuns.End(strings.TrimSpace(agentKey))
}

// IsRunAgentOnceActive 是否正在试跑。
func IsRunAgentOnceActive(agentKey string) bool {
	return runtime.LiveRuns.IsRunning(strings.TrimSpace(agentKey))
}

// RunAgentOnceAsync 在后台执行试跑；成功启动返回 Accepted=true。
func RunAgentOnceAsync(ctx context.Context, deps runtime.Deps, agentKey string) (RunOnceStartResult, error) {
	start := TryStartRunAgentOnce(agentKey)
	if !start.Accepted {
		return start, nil
	}
	key := strings.TrimSpace(agentKey)
	go func() {
		defer EndRunAgentOnce(key)
		_, _ = RunAgentOnce(context.Background(), deps, key)
	}()
	return start, nil
}
