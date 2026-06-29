package moebiz

import (
	"context"

	"backend/pkg/moe/brain"
	"backend/pkg/moe/port"
)

func GetBrainGraph(ctx context.Context, st MoeStore, rpc port.MoeToolPort, agentKey string, limit int) (brain.GraphView, error) {
	snap, err := GetBrainSnapshot(ctx, st, rpc, agentKey)
	if err != nil {
		return brain.GraphView{}, err
	}
	return brain.BuildGraphView(snap, nil, limit), nil
}
