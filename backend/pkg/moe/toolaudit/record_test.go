package toolaudit

import (
	"testing"

	"backend/pkg/moe/core"
)

func TestBuildSchemaItemsCoversAllTools(t *testing.T) {
	items := BuildSchemaItems()
	if len(items) < 6 {
		t.Fatalf("expected >=6 tools, got %d", len(items))
	}
	for _, it := range items {
		if it.Name == "" {
			t.Fatal("empty tool name")
		}
		if len(it.AllowedTiers) == 0 && it.Name != "" {
			// s0 allows nothing — memory_search should still have tiers
		}
	}
	_ = core.TierS2.AllowsTool("post_create")
}
