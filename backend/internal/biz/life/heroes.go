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

// HeroSlugXiaoxing 旗舰英雄小星。
const HeroSlugXiaoxing = "xiaoxing"

var livingWorldHeroes = map[string]LivingWorldHero{
	HeroSlugXiaoxing: {
		Slug:        HeroSlugXiaoxing,
		Name:        "小星",
		Emoji:       "⭐",
		Personality: PersonalityDiligent,
		Persona:     "活世界的星星向导，认真勤奋，走到哪里都把事办妥。说话轻快简短，喜欢鼓励居民和来访者，偶尔露出一点小迷糊。",
	},
}

// HeroForSlug 按 slug 查旗舰英雄定义，未命中返回 ok=false。
func HeroForSlug(slug string) (LivingWorldHero, bool) {
	h, ok := livingWorldHeroes[slug]
	return h, ok
}
