package lifebiz

import "time"

// LifeAction 行为枚举
type LifeAction string

const (
	ActionIdle        LifeAction = "idle"
	ActionWalking     LifeAction = "walking"
	ActionEating      LifeAction = "eating"
	ActionSleeping    LifeAction = "sleeping"
	ActionSeekingFood LifeAction = "seeking_food"
	ActionSeekingRest LifeAction = "seeking_rest"
	ActionWandering   LifeAction = "wandering"
	ActionTalking     LifeAction = "talking"
)

// LifeConfig 引擎配置
type LifeConfig struct {
	TickInterval   time.Duration // 默认 5s
	MaxEntities    int           // 每世界最大实体数，默认 50
	WorldName      string        // 默认 "default"
	FlushInterval  time.Duration // DB flush 间隔，默认 5s
	FlushBatchSize int           // 批量 flush 阈值，默认 100
}

// DefaultConfig 返回默认配置
func DefaultConfig() LifeConfig {
	return LifeConfig{
		TickInterval:   5 * time.Second,
		MaxEntities:    50,
		WorldName:      "default",
		FlushInterval:  5 * time.Second,
		FlushBatchSize: 100,
	}
}

// EntityDiff 增量变化（用于广播）
type EntityDiff struct {
	ID            uint       `json:"id"`
	Name          string     `json:"name"`
	Emoji         string     `json:"emoji"`
	Hunger        float64    `json:"hunger"`
	Energy        float64    `json:"energy"`
	Mood          float64    `json:"mood"`
	CurrentAction LifeAction `json:"action"`
	PositionX     float64    `json:"x"`
	PositionY     float64    `json:"y"`
}

// EventDiff 事件变化（用于广播）
type EventDiff struct {
	EntityID   uint    `json:"entity_id"`
	EntityType string  `json:"entity_type"`
	EventType  string  `json:"type"`
	Desc       string  `json:"desc"`
	PositionX  float64 `json:"x"`
	PositionY  float64 `json:"y"`
}

// TickBroadcast tick 广播数据
type TickBroadcast struct {
	Type    string      `json:"type"`     // "life_state"
	WorldID string      `json:"world_id"`
	Tick    int64       `json:"tick"`
	Changes TickChanges `json:"changes"`
}

// TickChanges tick 增量变化集合
type TickChanges struct {
	Entities []EntityDiff `json:"entities,omitempty"`
	Events   []EventDiff  `json:"events,omitempty"`
}
