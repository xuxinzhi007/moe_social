package moebiz

import (
	"context"
	"strings"

	"backend/pkg/moe/brain"
	"backend/pkg/moe/port"
	"backend/pkg/moe/runtime"
)

// GetBrainPresence 构建 Bot 游戏化在场状态。
func GetBrainPresence(ctx context.Context, st MoeStore, rpc port.MoeToolPort, refine brain.RefineDeps, agentKey string) (brain.PresenceView, error) {
	if err := requireStore(st); err != nil {
		return brain.PresenceView{}, err
	}
	key := strings.TrimSpace(agentKey)
	live := brain.LivePipelineStatus{}
	if runtime.LiveRuns.IsRunning(key) {
		live.Running = true
		if snap, ok := runtime.LiveRuns.SnapshotForAgent(key); ok {
			label := strings.TrimSpace(snap.ActiveLabel)
			if label == "" {
				label = strings.TrimSpace(snap.CurrentPhase)
			}
			live.StepLabel = label
		}
	}
	deps := brain.RpgDeps{DB: st.WithContext(ctx).Raw(), RPC: rpc, Inference: refine}
	return brain.BuildPresence(ctx, deps, key, live)
}

// UpdateBrainDreamSchedule 更新定时入梦 cron。
func UpdateBrainDreamSchedule(ctx context.Context, st MoeStore, agentKey string, enabled bool, cronExpr string) (brain.RpgConfig, error) {
	if err := requireStore(st); err != nil {
		return brain.RpgConfig{}, err
	}
	return brain.UpdateDreamSchedule(st.WithContext(ctx).Raw(), strings.TrimSpace(agentKey), enabled, cronExpr)
}

// UpdateBrainAutonomousMind 开关自主思考。
func UpdateBrainAutonomousMind(ctx context.Context, st MoeStore, agentKey string, enabled bool) (brain.RpgConfig, error) {
	if err := requireStore(st); err != nil {
		return brain.RpgConfig{}, err
	}
	return brain.UpdateAutonomousMind(st.WithContext(ctx).Raw(), strings.TrimSpace(agentKey), enabled)
}

// GenerateBrainThought 生成并缓存模型想法。
func GenerateBrainThought(ctx context.Context, st MoeStore, rpc port.MoeToolPort, refine brain.RefineDeps, agentKey string) (string, error) {
	if err := requireStore(st); err != nil {
		return "", err
	}
	deps := brain.RpgDeps{DB: st.WithContext(ctx).Raw(), RPC: rpc, Inference: refine}
	return brain.GenerateAutonomousThought(ctx, deps, strings.TrimSpace(agentKey))
}
