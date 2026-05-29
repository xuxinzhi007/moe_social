package brain

import "testing"

func TestBuildGraphView_agentAndEpisode(t *testing.T) {
	snap := &Snapshot{
		AgentKey:    "moe_guide",
		DisplayName: "Moe 向导",
		Episodes: []EpisodeItem{
			{
				ID:           1,
				Content:      "周六早上咖啡",
				Tags:         []string{"topic:日常"},
				QualityScore: 80,
				MemoryKey:    "bot_post:abc",
			},
		},
		Memories: []MemoryItem{
			{Key: "bot_post:abc", Value: "喜欢周末咖啡"},
		},
	}
	view := BuildGraphView(snap, nil, 50)
	if len(view.Nodes) < 3 {
		t.Fatalf("expected nodes, got %d", len(view.Nodes))
	}
	if len(view.Edges) < 2 {
		t.Fatalf("expected edges, got %d", len(view.Edges))
	}
}
