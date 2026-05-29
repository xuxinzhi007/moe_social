package moebiz

import (
	"context"
	"strings"

	"backend/model"
	"backend/pkg/memory"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/port"
)

// GetBrainGraph 构建 Bot 知识图谱（自传 + 记忆 + 标签 + 关系边）。
func GetBrainGraph(ctx context.Context, st MoeStore, rpc port.MoeToolPort, agentKey string, limit int) (brain.GraphView, error) {
	snap, err := GetBrainSnapshot(ctx, st, rpc, agentKey)
	if err != nil {
		return brain.GraphView{}, err
	}
	relations := loadBotMemoryRelations(ctx, st, snap)
	return brain.BuildGraphView(snap, relations, limit), nil
}

func loadBotMemoryRelations(ctx context.Context, st MoeStore, snap *brain.Snapshot) []memory.Relation {
	if snap == nil || snap.BotUserID == 0 {
		return nil
	}
	db := dbFromStore(ctx, st)
	if db == nil {
		return nil
	}
	var rows []model.UserMemoryRelation
	if err := db.Where("user_id = ?", snap.BotUserID).Limit(200).Find(&rows).Error; err != nil {
		return nil
	}
	out := make([]memory.Relation, 0, len(rows))
	for _, r := range rows {
		rel := strings.TrimSpace(r.Relation)
		if rel == "" {
			rel = "related"
		}
		out = append(out, memory.Relation{
			FromKey:  r.FromKey,
			ToKey:    r.ToKey,
			Relation: rel,
			Weight:   r.Weight,
		})
	}
	return out
}
