package utils

import "testing"

func TestLandingFeedbackCategoryLabel(t *testing.T) {
	cases := map[string]string{
		"feature": "功能建议",
		"bug":     "问题反馈",
		"other":   "其他",
		"":        "其他",
	}
	for in, want := range cases {
		if got := landingFeedbackCategoryLabel(in); got != want {
			t.Fatalf("landingFeedbackCategoryLabel(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestBuildLandingFeedbackCard(t *testing.T) {
	card := buildLandingFeedbackCard(LandingFeedbackNotification{
		ID:       42,
		Email:    "user@example.com",
		Category: "feature",
		Content:  "希望增加暗色模式",
		Source:   "official-site",
		ClientIP: "127.0.0.1",
	})
	header, ok := card["header"].(map[string]interface{})
	if !ok {
		t.Fatal("missing header")
	}
	title, ok := header["title"].(map[string]interface{})
	if !ok || title["content"] != "Moe Social · 官网新反馈" {
		t.Fatalf("unexpected title: %#v", title)
	}
}
