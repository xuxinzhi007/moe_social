package moebiz

import (
	"context"
	"strings"

	"backend/pkg/moe/brain"
	"backend/pkg/moe/port"

	"gorm.io/gorm"
)

// GetBrainSnapshot 加载 Bot 大脑观测快照。
func GetBrainSnapshot(ctx context.Context, db *gorm.DB, rpc port.SuperPort, agentKey string) (*brain.Snapshot, error) {
	return brain.LoadSnapshot(ctx, db, rpc, strings.TrimSpace(agentKey))
}

// UpdateBrainPolicy 更新标签策略后返回最新快照。
func UpdateBrainPolicy(ctx context.Context, db *gorm.DB, rpc port.SuperPort, agentKey string, forbiddenTags, preferredTags []string) (*brain.Snapshot, error) {
	key := strings.TrimSpace(agentKey)
	forbidden := brain.ParseTagList(strings.Join(forbiddenTags, "\n"))
	preferred := brain.ParseTagList(strings.Join(preferredTags, "\n"))
	if err := brain.UpdatePolicy(db, key, forbidden, preferred); err != nil {
		return nil, err
	}
	return GetBrainSnapshot(ctx, db, rpc, key)
}
