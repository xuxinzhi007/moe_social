package flowexec

import "testing"

func TestCompileDefaultPostingPlan(t *testing.T) {
	plan := DefaultPostingPlan()
	if len(plan.Nodes) < 5 {
		t.Fatalf("expected >=5 nodes, got %d", len(plan.Nodes))
	}
	hasLLM, hasPost := false, false
	for _, n := range plan.Nodes {
		k := NodeExecKind(n)
		if k == "llm_generate" {
			hasLLM = true
		}
		if k == "post_create" {
			hasPost = true
		}
	}
	if !hasLLM || !hasPost {
		t.Fatalf("missing llm or post: llm=%v post=%v", hasLLM, hasPost)
	}
}

func TestCompileRejectsCycle(t *testing.T) {
	g := Graph{
		EntryNodeID: "a",
		Nodes: []GraphNode{
			{ID: "a", Type: "step", Kind: "load_runtime", Enabled: true},
			{ID: "b", Type: "step", Kind: "llm_generate", Enabled: true},
		},
		Edges: []GraphEdge{
			{Source: "a", Target: "b", Kind: "default"},
			{Source: "b", Target: "a", Kind: "default"},
		},
	}
	_, err := Compile(g)
	if err == nil {
		t.Fatal("expected cycle error")
	}
}
