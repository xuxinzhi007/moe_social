package utils

import "testing"

func TestStableDefaultAvatarIsUniqueAndStable(t *testing.T) {
	first := StableDefaultAvatar(7)
	second := StableDefaultAvatar(8)
	if first == "" || second == "" || first == second {
		t.Fatalf("avatars = %q %q, want distinct non-empty urls", first, second)
	}
	if StableDefaultAvatar(7) != first {
		t.Fatal("same user id produced a different avatar")
	}
	if NeedsStableDefaultAvatar(first) {
		t.Fatalf("seeded avatar %q still looks ephemeral", first)
	}
}

func TestNeedsStableDefaultAvatar(t *testing.T) {
	cases := []struct {
		raw  string
		want bool
	}{
		{raw: "", want: true},
		{raw: "https://picsum.photos/150", want: true},
		{raw: "https://picsum.photos/150/150", want: true},
		{raw: "https://picsum.photos/seed/moe-7/150", want: false},
		{raw: "/api/images/1_name__a.png", want: false},
		{raw: "https://cdn.example.com/a.png", want: false},
	}
	for _, tc := range cases {
		if got := NeedsStableDefaultAvatar(tc.raw); got != tc.want {
			t.Fatalf("NeedsStableDefaultAvatar(%q) = %v, want %v", tc.raw, got, tc.want)
		}
	}
}
