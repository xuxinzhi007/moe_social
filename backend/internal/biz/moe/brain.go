package moebiz

import (
	"context"
	"strings"

	"backend/pkg/moe/brain"
	"backend/pkg/moe/port"
)

// GetBrainSnapshot 加载 Bot 大脑观测快照。
func GetBrainSnapshot(ctx context.Context, store MoeStore, rpc port.MoeToolPort, agentKey string) (*brain.Snapshot, error) {
	if err := requireStore(store); err != nil {
		return nil, err
	}
	return brain.LoadSnapshot(ctx, store.WithContext(ctx).Raw(), rpc, strings.TrimSpace(agentKey))
}

// UpdateBrainPolicy 更新标签策略后返回最新快照。
func UpdateBrainPolicy(ctx context.Context, store MoeStore, rpc port.MoeToolPort, agentKey string, forbiddenTags, preferredTags []string) (*brain.Snapshot, error) {
	if err := requireStore(store); err != nil {
		return nil, err
	}
	key := strings.TrimSpace(agentKey)
	forbidden := brain.ParseTagList(strings.Join(forbiddenTags, "\n"))
	preferred := brain.ParseTagList(strings.Join(preferredTags, "\n"))
	st := store.WithContext(ctx)
	if err := st.UpdateRuntimePolicy(ctx, key, strings.Join(forbidden, "\n"), strings.Join(preferred, "\n")); err != nil {
		return nil, err
	}
	return GetBrainSnapshot(ctx, store, rpc, key)
}
