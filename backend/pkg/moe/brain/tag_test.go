package brain

import "testing"

func TestExtractTags(t *testing.T) {
	tags := ExtractTags("刚画完线稿，周末想休息😂 大家有啥推荐吗？", "happy", 0)
	found := false
	for _, t := range tags {
		if t == "type:提问" {
			found = true
		}
	}
	if !found {
		t.Fatalf("expected type:提问 in %v", tags)
	}
}

func TestTagsConflict(t *testing.T) {
	hits := TagsConflict([]string{"risk:诗意腔", "mood:happy"}, []string{"risk:诗意腔"})
	if len(hits) != 1 {
		t.Fatalf("expected 1 hit, got %v", hits)
	}
}
