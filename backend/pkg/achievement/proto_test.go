package achievement

import (
	"testing"
)

func TestUnlocksToProto(t *testing.T) {
	if UnlocksToProto(nil) != nil {
		t.Fatal("nil input should return nil slice")
	}
	out := UnlocksToProto([]UnlockResult{
		{BadgeID: "welcome_aboard", Name: "初来乍到", ExpGranted: 20, LevelUp: true, NewLevel: 2},
	})
	if len(out) != 1 || out[0].BadgeId != "welcome_aboard" || out[0].ExpGranted != 20 {
		t.Fatalf("unexpected proto: %+v", out)
	}
}

func TestBadgesToProto(t *testing.T) {
	out := BadgesToProto([]BadgeDTO{
		{ID: "first_post", Name: "初出茅庐", Progress: 0.5, IsUnlocked: false},
	})
	if len(out) != 1 || out[0].Id != "first_post" || out[0].Progress != 0.5 {
		t.Fatalf("unexpected badges proto: %+v", out)
	}
}
