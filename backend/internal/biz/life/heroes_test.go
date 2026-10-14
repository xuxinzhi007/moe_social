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
	for _, e := range entities[1:] {
		if e.HeroSlug != "" {
			t.Errorf("NPC %s hero_slug=%q, want empty", e.Name, e.HeroSlug)
		}
	}
}
