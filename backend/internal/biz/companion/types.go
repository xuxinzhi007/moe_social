package companionbiz

import "time"

// Profile AI 伙伴身份（值类型，由 model.CompanionProfile 转换）。
type Profile struct {
	ID                uint
	UserID            uint
	Name              string
	Emoji             string
	Persona           string
	PersonalityTraits []string // JSON 解析后
	GreetingStyle     string   // warm / playful / calm
	RelationshipLevel int
	IntimacyScore     float64
	SystemPromptOverride string
	AgentID           string
	LifeEntityID      int
}

// Memory AI 伙伴持久记忆。
type Memory struct {
	ID              uint
	UserID          uint
	MemoryType      string // conversation / milestone / preference / fact
	Content         string
	Importance      int // 0=7天 / 1=30天 / 2=永久
	SourceChatLogID uint
	ExpiresAt       *time.Time
	CreatedAt       time.Time
}

// State 伙伴当前人格化状态（前端直接展示）。
type State struct {
	MoodThought   string  // "今天心情不错，想找人聊天"
	ActivityLabel string  // "在窗边发呆"
	Greeting      string  // "嘿，你来啦！"
	Moments       []Moment
	Mood          float64
	Hunger        float64
	Energy        float64
}

// Moment 伙伴动态卡片（类朋友圈）。
type Moment struct {
	Text      string
	Icon      string
	TimeLabel string
}

// ChatLog 聊天记录。
type ChatLog struct {
	ID        uint
	UserID    uint
	Role      string // user / assistant
	Content   string
	CreatedAt time.Time
}

// memoryExpiresAt 根据 importance 计算记忆过期时间。
// 0=7天 / 1=30天 / 2=永久(nil)
func memoryExpiresAt(importance int) *time.Time {
	if importance >= 2 {
		return nil // 永久
	}
	days := 7
	if importance == 1 {
		days = 30
	}
	t := time.Now().Add(time.Duration(days) * 24 * time.Hour)
	return &t
}
