package memory

import (
	"testing"
	"time"
)

func TestRerankCandidates_MMRReducesDuplicate(t *testing.T) {
	now := time.Now()
	candidates := []rankedCandidate{
		{rec: Record{Key: "a", Value: "coffee", UpdatedAt: now}, score: 0.9},
		{rec: Record{Key: "b", Value: "latte", UpdatedAt: now}, score: 0.88},
		{rec: Record{Key: "c", Value: "music", UpdatedAt: now}, score: 0.5},
	}
	emb := map[string][]float32{
		"a": {1, 0, 0},
		"b": {0.99, 0.01, 0},
		"c": {0, 1, 0},
	}
	out := RerankCandidates(candidates, "coffee", []float32{1, 0, 0}, emb, 2, RerankConfig{
		Enabled: true, TopK: 10, MMRLambda: 0.7,
	})
	if len(out) != 2 {
		t.Fatalf("want 2 got %d", len(out))
	}
	// 应优先 a + c，而非 a + b（过于相似）
	if out[0].rec.Key != "a" {
		t.Fatalf("first want a got %s", out[0].rec.Key)
	}
	if out[1].rec.Key == "b" {
		t.Fatal("expected diverse second pick, got b")
	}
}

func TestExpandGraph(t *testing.T) {
	records := []Record{
		{Key: "hobby", Value: "画画", MemoryType: "preference"},
		{Key: "user_preference", Value: "爵士", MemoryType: "preference"},
	}
	g := BuildMemoryGraph(records, nil)
	seeds := map[string]float64{"hobby": 1.0}
	exp := ExpandGraph(g, seeds, DefaultGraphConfig())
	if _, ok := exp["user_preference"]; !ok {
		t.Fatalf("expected neighbor user_preference, got %v", exp)
	}
}
