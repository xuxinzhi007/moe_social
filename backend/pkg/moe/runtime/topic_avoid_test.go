package runtime

import "testing"

func TestAppendTopicAvoid(t *testing.T) {
	got := appendTopicAvoid("", "深夜画线稿，手酸")
	if got == "" {
		t.Fatal("expected non-empty avoid block")
	}
	got2 := appendTopicAvoid(got, "深夜画线稿，手酸")
	if got != got2 {
		t.Fatal("duplicate reject should not grow block")
	}
}
