package moebiz

import (
	"context"
	"strings"

	"backend/pkg/moe/brain"
	"backend/pkg/moe/port"
)

// GetBrainRpg 加载 Memory RPG 快照。
func GetBrainRpg(ctx context.Context, st MoeStore, rpc port.MoeToolPort, refine brain.RefineDeps, agentKey string) (brain.RpgView, error) {
	if err := requireStore(st); err != nil {
		return brain.RpgView{}, err
	}
	deps := brain.RpgDeps{DB: st.WithContext(ctx).Raw(), RPC: rpc, Inference: refine}
	return brain.LoadRpgView(ctx, deps, strings.TrimSpace(agentKey))
}

// RunBrainDream 入梦 consolidation。
func RunBrainDream(ctx context.Context, st MoeStore, rpc port.MoeToolPort, refine brain.RefineDeps, agentKey string, skipCurate bool) (brain.DreamResult, error) {
	if err := requireStore(st); err != nil {
		return brain.DreamResult{}, err
	}
	deps := brain.RpgDeps{DB: st.WithContext(ctx).Raw(), RPC: rpc, Inference: refine}
	return brain.RunDream(ctx, deps, agentKey, skipCurate)
}

// CompressBrainMemories 压缩近期认可自传。
func CompressBrainMemories(ctx context.Context, st MoeStore, rpc port.MoeToolPort, refine brain.RefineDeps, agentKey string, days int) (brain.CompressResult, error) {
	if err := requireStore(st); err != nil {
		return brain.CompressResult{}, err
	}
	deps := brain.RpgDeps{DB: st.WithContext(ctx).Raw(), RPC: rpc, Inference: refine}
	return brain.CompressMemories(ctx, deps, agentKey, days)
}

// TidyBrainFragments 整理低分碎片。
func TidyBrainFragments(ctx context.Context, st MoeStore, rpc port.MoeToolPort, refine brain.RefineDeps, agentKey string, maxEpisodes int) (brain.TidyResult, error) {
	if err := requireStore(st); err != nil {
		return brain.TidyResult{}, err
	}
	deps := brain.RpgDeps{DB: st.WithContext(ctx).Raw(), RPC: rpc, Inference: refine}
	return brain.TidyFragments(ctx, deps, agentKey, maxEpisodes)
}

// LockBrainSkill 锁定/解锁技能 tag。
func LockBrainSkill(ctx context.Context, st MoeStore, agentKey, tag string, lock bool) ([]string, error) {
	if err := requireStore(st); err != nil {
		return nil, err
	}
	return brain.LockSkill(st.WithContext(ctx).Raw(), strings.TrimSpace(agentKey), tag, lock)
}

// ForgetBrainMemory 遗忘 bot 记忆。
func ForgetBrainMemory(ctx context.Context, st MoeStore, rpc port.MoeToolPort, refine brain.RefineDeps, agentKey, memoryKey string) (bool, error) {
	if err := requireStore(st); err != nil {
		return false, err
	}
	deps := brain.RpgDeps{DB: st.WithContext(ctx).Raw(), RPC: rpc, Inference: refine}
	return brain.ForgetMemory(ctx, deps, agentKey, memoryKey)
}
