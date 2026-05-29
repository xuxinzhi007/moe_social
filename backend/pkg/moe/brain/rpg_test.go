package brain

import "testing"

func TestLevelFromXP(t *testing.T) {
	level, ring, next := levelFromXP(0)
	if level != 1 || ring != 0 || next != 100 {
		t.Fatalf("got level=%d ring=%d next=%d", level, ring, next)
	}
	level, ring, next = levelFromXP(150)
	if level != 2 || ring != 50 || next != 50 {
		t.Fatalf("got level=%d ring=%d next=%d", level, ring, next)
	}
}

func TestFragmentStatus(t *testing.T) {
	if fragmentStatus(true, 80) != "solid" {
		t.Fatal("expected solid")
	}
	if fragmentStatus(false, 55) != "fragment" {
		t.Fatal("expected fragment")
	}
	if fragmentStatus(false, 30) != "cracked" {
		t.Fatal("expected cracked")
	}
}

func TestSkillLevel(t *testing.T) {
	if skillLevel(0) != 1 {
		t.Fatal("expected 1")
	}
	if skillLevel(12) != 3 {
		t.Fatal("expected 3")
	}
	if skillLevel(100) != 5 {
		t.Fatal("expected cap 5")
	}
}

func TestParseRpgConfig(t *testing.T) {
	raw := `{"rpg":{"total_xp":42,"locked_skills":["tone:口语"]}}`
	cfg := parseRpgConfig(raw)
	if cfg.TotalXP != 42 || len(cfg.LockedSkills) != 1 {
		t.Fatalf("unexpected cfg: %+v", cfg)
	}
}
