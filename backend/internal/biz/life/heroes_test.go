package lifebiz

import "testing"

func TestHeroForSlug(t *testing.T) {
	h, ok := HeroForSlug(HeroSlugXiaoxing)
	if !ok {
		t.Fatalf("hero %q should be defined", HeroSlugXiaoxing)
	}
	if h.Name != "小星" || h.Emoji != "⭐" {
		t.Errorf("hero identity mismatch: %s %s", h.Name, h.Emoji)
	}
	if h.Personality != PersonalityDiligent {
		t.Errorf("hero personality=%q, want %q", h.Personality, PersonalityDiligent)
	}
	if h.Persona == "" {
		t.Error("hero persona should not be empty (needed for chat prompt)")
	}

	if _, ok := HeroForSlug("not-a-hero"); ok {
		t.Error("unknown slug should miss")
	}
}

func TestSeedHeroBinding(t *testing.T) {
	entities := createSeedEntities("w-test")
	hero := entities[0]
	if hero.HeroSlug != HeroSlugXiaoxing {
		t.Errorf("flagship seed hero_slug=%q, want %q", hero.HeroSlug, HeroSlugXiaoxing)
	}
	def, _ := HeroForSlug(HeroSlugXiaoxing)
	if hero.Name != def.Name || hero.Emoji != def.Emoji || hero.Personality != def.Personality {
		t.Errorf("seed hero should mirror hero definition, got %+v", hero)
	}
	seen := map[string]bool{}
	for _, e := range entities {
		if e.HeroSlug == "" {
			continue
		}
		seen[e.HeroSlug] = true
	}
	for _, hero := range LivingWorldRoster() {
		if !seen[hero.Slug] {
			t.Errorf("seed missing roster hero %s", hero.Slug)
		}
	}
}

func TestRosterPersonalitiesCovered(t *testing.T) {
	if len(LivingWorldRoster()) != 4 {
		t.Fatalf("roster len=%d, want 4", len(LivingWorldRoster()))
	}
	for _, hero := range LivingWorldRoster() {
		if _, ok := personalityTable[hero.Personality]; !ok {
			t.Errorf("%s personality %q missing from preference table", hero.Slug, hero.Personality)
		}
	}
}
