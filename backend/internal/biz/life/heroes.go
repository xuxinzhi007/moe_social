package lifebiz

// LivingWorldHero 旗舰英雄角色卡定义，生命世界侧 SSOT。
// 营地页、小家闲聊、Arena 等消费方只读引用，不各自复制。
type LivingWorldHero struct {
	Slug        string // 稳定标识，落库到 LifeEntity.hero_slug。
	Name        string
	Emoji       string
	Personality string // 对齐 personality.go 的性格 key。
	Persona     string // 角色卡描述，供小家闲聊拼装 prompt。
}

const (
	// HeroSlugXiaoxing 旗舰英雄小星。
	HeroSlugXiaoxing = "xiaoxing"
	// HeroSlugLanxing 首发英雄澜星。
	HeroSlugLanxing = "lanxing"
	// HeroSlugTutu 首发英雄兔突。
	HeroSlugTutu = "tutu"
	// HeroSlugMaoying 首发英雄猫影。
	HeroSlugMaoying = "maoying"
)

var livingWorldHeroes = map[string]LivingWorldHero{
	HeroSlugXiaoxing: {
		Slug:        HeroSlugXiaoxing,
		Name:        "小星",
		Emoji:       "⭐",
		Personality: PersonalityDiligent,
		Persona:     "活世界的星星向导，认真勤奋，走到哪里都把事办妥。说话轻快简短，喜欢鼓励居民和来访者，偶尔露出一点小迷糊。",
	},
	HeroSlugLanxing: {
		Slug:        HeroSlugLanxing,
		Name:        "澜星",
		Emoji:       "✨",
		Personality: PersonalityCurious,
		Persona:     "晨潮星术士，对营地里每件新鲜事都要看一眼。说话慢，喜欢把看到的事讲给同伴听。",
	},
	HeroSlugTutu: {
		Slug:        HeroSlugTutu,
		Name:        "兔突",
		Emoji:       "🐰",
		Personality: PersonalitySocial,
		Persona:     "星辉剑士，走到哪都先跟人打招呼。话不多，但会把旁边的居民拢到一起。",
	},
	HeroSlugMaoying: {
		Slug:        HeroSlugMaoying,
		Name:        "猫影",
		Emoji:       "🐱",
		Personality: PersonalitySleepy,
		Persona:     "月霜游侠，白天爱找阴凉处打盹，夜里才慢慢走动。被叫醒时会轻轻抱怨一句。",
	},
}

// rosterOrder 活世界入驻顺序：旗舰在前，随后是三名首发英雄。
var rosterOrder = []string{
	HeroSlugXiaoxing,
	HeroSlugLanxing,
	HeroSlugTutu,
	HeroSlugMaoying,
}

// LivingWorldRoster 返回全量入驻英雄。未知 slug 不会出现。
func LivingWorldRoster() []LivingWorldHero {
	out := make([]LivingWorldHero, 0, len(rosterOrder))
	for _, slug := range rosterOrder {
		hero, ok := livingWorldHeroes[slug]
		if !ok {
			continue
		}
		out = append(out, hero)
	}
	return out
}

// HeroForSlug 按 slug 查旗舰英雄定义，未命中返回 ok=false。
func HeroForSlug(slug string) (LivingWorldHero, bool) {
	h, ok := livingWorldHeroes[slug]
	return h, ok
}
