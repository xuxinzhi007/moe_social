package companionbiz

import (
	"fmt"
	"strings"
	"time"

	"backend/model"
)

// computeState 从 LifeEntity 数值 + Profile 人格 → 人格化 State。
// events 始终可转 Moments（含实体已软删除），作为「TA 的日常」世界侧 SSOT。
func computeState(profile *Profile, entity *model.LifeEntity, events []model.LifeEventLog) *State {
	moments := buildMoments(events)
	greeting := greetingForStyle(profile, time.Now().Hour())
	if entity == nil {
		thought := "刚来到这里，一切都是新的"
		activity := "刚上线"
		if profile != nil && profile.LifeEntityID > 0 {
			thought = "世界里暂时找不到 TA，绑定还在，去世界看看吧"
			activity = "暂时不在舞台上"
		}
		return &State{
			MoodThought:   thought,
			ActivityLabel: activity,
			Greeting:      greeting,
			Moments:       moments,
			Mood:          70,
			Hunger:        80,
			Energy:        80,
			EntityAlive:   false,
		}
	}
	if !entity.IsAlive {
		return &State{
			MoodThought:   "TA 暂时离开了舞台，日常记录还在这里",
			ActivityLabel: "已离开舞台",
			Greeting:      greeting,
			Moments:       moments,
			Mood:          entity.Mood,
			Hunger:        entity.Hunger,
			Energy:        entity.Energy,
			EntityAlive:   false,
		}
	}
	return &State{
		MoodThought:   moodThought(profile, entity.Mood, entity.Hunger, entity.Energy),
		ActivityLabel: activityLabel(entity),
		Greeting:      greeting,
		Moments:       moments,
		Mood:          entity.Mood,
		Hunger:        entity.Hunger,
		Energy:        entity.Energy,
		EntityAlive:   true,
	}
}

// moodThought 根据 personality_traits 变化心情表达风格。
func moodThought(profile *Profile, mood, hunger, energy float64) string {
	style := profileStyle(profile)
	switch {
	case mood >= 80 && energy >= 60:
		return pickByStyle(style,
			"今天心情不错，想找人聊天",
			"超开心！快来跟我玩呀",
			"心情很好，适合做点什么")
	case mood >= 60:
		return pickByStyle(style,
			"还行吧，随便逛逛",
			"嘿嘿，今天还不错",
			"今天挺舒服的")
	case mood >= 40:
		return pickByStyle(style,
			"有点无聊，不知道干嘛",
			"嗯…有点闷",
			"一般般吧")
	case hunger < 30:
		return pickByStyle(style,
			"有点饿了，先不想说话",
			"饿死我了…",
			"肚子在叫，不太想动")
	case energy < 30:
		return pickByStyle(style,
			"好困，想躺一会儿",
			"困得不行了zzz",
			"有点累，休息一下")
	default:
		return pickByStyle(style,
			"心情不太好…",
			"有点不开心",
			"今天有点低落")
	}
}

// activityLabel 把 LifeEntity.CurrentAction 翻译成社交化表达。
func activityLabel(entity *model.LifeEntity) string {
	action := strings.TrimSpace(entity.CurrentAction)
	switch action {
	case "idle":
		return "在发呆"
	case "walking", "wandering":
		return "在四处逛逛"
	case "eating":
		return "在吃东西"
	case "sleeping", "seeking_rest":
		return "在休息"
	case "seeking_food":
		return "在找吃的"
	case "talking":
		return "在和朋友聊天"
	case "playing":
		return "在玩"
	default:
		if action == "" {
			return "刚上线"
		}
		return "在忙"
	}
}

// greetingForStyle 根据当前小时 + 问候风格生成问候语。
func greetingForStyle(profile *Profile, hour int) string {
	timeOfDay := timeOfDayLabel(hour)
	style := profileStyle(profile)
	switch style {
	case "playful":
		switch timeOfDay {
		case "morning":
			return "早上好呀～新的一天开始啦！"
		case "afternoon":
			return "下午好！有没有想我？"
		case "evening":
			return "晚上好～今天过得怎么样？"
		default:
			return "深夜了还不睡，来找你玩啦"
		}
	case "calm":
		switch timeOfDay {
		case "morning":
			return "早安，今天也是平静的一天"
		case "afternoon":
			return "下午好，休息一下吧"
		case "evening":
			return "晚上好，今天辛苦了"
		default:
			return "夜深了，早点休息"
		}
	default: // warm
		switch timeOfDay {
		case "morning":
			return "早上好！今天也要开心哦"
		case "afternoon":
			return "下午好，记得喝水"
		case "evening":
			return "晚上好，今天辛苦啦"
		default:
			return "这么晚了，注意休息呀"
		}
	}
}

// buildMoments 从 LifeEventLog 转化为动态卡片。
func buildMoments(events []model.LifeEventLog) []Moment {
	if len(events) == 0 {
		return nil
	}
	limit := 8
	if len(events) < limit {
		limit = len(events)
	}
	out := make([]Moment, 0, limit)
	for i := 0; i < limit; i++ {
		e := events[i]
		out = append(out, Moment{
			Text:      momentText(e),
			Icon:      momentIcon(e.EventType),
			TimeLabel: formatTimeAgo(e.CreatedAt),
		})
	}
	return out
}

func momentText(e model.LifeEventLog) string {
	desc := strings.TrimSpace(e.Description)
	if desc != "" {
		return desc
	}
	switch e.EventType {
	case "birth":
		return "来到了这个世界"
	case "eat":
		return "吃了点东西"
	case "sleep":
		return "休息了一会儿"
	case "social":
		return "交到了新朋友"
	case "explore":
		return "去探索了一下周围"
	case "growth":
		return "成长了！"
	default:
		return "发生了点什么"
	}
}

func momentIcon(eventType string) string {
	switch eventType {
	case "birth":
		return "🌟"
	case "eat":
		return "🍜"
	case "sleep":
		return "💤"
	case "social":
		return "💬"
	case "explore":
		return "🗺️"
	case "growth":
		return "📈"
	case "death":
		return "💔"
	default:
		return "✨"
	}
}

func formatTimeAgo(t time.Time) string {
	diff := time.Since(t)
	switch {
	case diff < time.Minute:
		return "刚刚"
	case diff < time.Hour:
		return fmt.Sprintf("%d分钟前", int(diff.Minutes()))
	case diff < 24*time.Hour:
		return fmt.Sprintf("%d小时前", int(diff.Hours()))
	default:
		return fmt.Sprintf("%d天前", int(diff.Hours()/24))
	}
}

// ── 辅助函数 ──

func profileStyle(profile *Profile) string {
	if profile == nil {
		return "warm"
	}
	style := strings.ToLower(strings.TrimSpace(profile.GreetingStyle))
	if style == "" {
		return "warm"
	}
	return style
}

func pickByStyle(style, warm, playful, calm string) string {
	switch style {
	case "playful":
		return playful
	case "calm":
		return calm
	default:
		return warm
	}
}

func timeOfDayLabel(hour int) string {
	switch {
	case hour >= 5 && hour < 12:
		return "morning"
	case hour >= 12 && hour < 18:
		return "afternoon"
	case hour >= 18 && hour < 23:
		return "evening"
	default:
		return "night"
	}
}
