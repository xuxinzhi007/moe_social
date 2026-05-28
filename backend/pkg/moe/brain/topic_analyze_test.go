package brain

import "testing"

func TestAnalyzeTopicsRules(t *testing.T) {
	a := AnalyzeTopicsRules("我正在深夜为手绘作品做最后的调整，手心有些微微发烫")
	if a.Scene != "深夜" {
		t.Fatalf("scene=%q", a.Scene)
	}
	if a.Activity != "手绘创作" {
		t.Fatalf("activity=%q", a.Activity)
	}
	foundHand := false
	for _, tag := range a.Tags {
		if tag == "topic:手绘" {
			foundHand = true
		}
	}
	if !foundHand {
		t.Fatalf("expected topic:手绘 in %v", a.Tags)
	}
}

func TestAnalyzeAndTagContentRulesOnly(t *testing.T) {
	deps := Deps{}
	tags := AnalyzeAndTagContent(nil, deps, "bot_a", "周末想去逛手办展，有同好吗？", "happy", 0)
	if len(tags) < 2 {
		t.Fatalf("expected multiple tags, got %v", tags)
	}
}

func TestTopicKeysFromTags(t *testing.T) {
	keys := topicKeysFromTags([]string{"scene:深夜", "activity:手绘", "mood:happy"})
	if len(keys) != 2 {
		t.Fatalf("expected 2 topic keys, got %v", keys)
	}
}
