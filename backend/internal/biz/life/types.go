package lifebiz

import (
	"encoding/json"
	"time"
)

// LifeAction represents a coarse-grained entity action.
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
	ActionReproducing LifeAction = "reproducing"
	ActionDying       LifeAction = "dying"
	ActionFleeing     LifeAction = "fleeing"  // 逃跑（躲避捕食者）
	ActionPlaying     LifeAction = "playing"  // 玩耍（与朋友互动）
)

// LifeConfig controls the in-process life engine.
type LifeConfig struct {
	TickInterval          time.Duration
	MaxEntities           int
	WorldName             string
	FlushInterval         time.Duration
	FlushBatchSize        int
	GridWidth             int
	GridHeight            int
	ActionCooldownSeconds int // 用户操作冷却时间（秒）
}

// DefaultConfig returns the default engine config.
func DefaultConfig() LifeConfig {
	return LifeConfig{
		TickInterval:          5 * time.Second,
		MaxEntities:           50,
		WorldName:             "default",
		FlushInterval:         5 * time.Second,
		FlushBatchSize:        100,
		GridWidth:             32,
		GridHeight:            18,
		ActionCooldownSeconds: 3,
	}
}

// WorldCell stores a lightweight environmental simulation cell.
type WorldCell struct {
	Terrain   string  `json:"terrain"`
	Food      float64 `json:"food"`
	Moisture  float64 `json:"moisture"`
	Danger    float64 `json:"danger"`
	Habitable bool    `json:"habitable"`
}

// WorldGrid is a low-cost ecological world layer.
type WorldGrid struct {
	Width   int           `json:"width"`
	Height  int           `json:"height"`
	Cells   [][]WorldCell `json:"cells,omitempty"`
	Weather string        `json:"weather,omitempty"` // 全局天气状态
}

// WorldEventType 世界事件类型
type WorldEventType string

const (
	WorldEventRain      WorldEventType = "weather_rain"
	WorldEventDrought   WorldEventType = "weather_drought"
	WorldEventStorm     WorldEventType = "disaster_storm"
	WorldEventDepletion WorldEventType = "resource_depletion"
	WorldEventHeatwave  WorldEventType = "weather_heatwave"   // 热浪
	WorldEventFog       WorldEventType = "weather_fog"         // 大雾
	WorldEventAbundance WorldEventType = "resource_abundance"  // 资源丰饶
	WorldEventMigration WorldEventType = "event_migration"     // 迁徙潮
)

// GridPos 网格坐标
type GridPos struct {
	X int `json:"x"`
	Y int `json:"y"`
}

// WorldEventState 活跃世界事件状态
type WorldEventState struct {
	Type           WorldEventType
	Active         bool
	RemainingTicks int
	AffectedCells  []GridPos // 受影响的网格坐标
	Intensity      float64
}

// WorldEventDiff 广播用
type WorldEventDiff struct {
	Type      string  `json:"type"`
	Active    bool    `json:"active"`
	Intensity float64 `json:"intensity"`
	Message   string  `json:"message,omitempty"`
}

// WorldSummary provides a compact ecosystem overview for UI and telemetry.
type WorldSummary struct {
	EntityCount    int      `json:"entity_count"`
	AliveCount     int      `json:"alive_count"`
	BirthCount     int      `json:"birth_count"`
	DeathCount     int      `json:"death_count"`
	AvgHunger      float64  `json:"avg_hunger"`
	AvgEnergy      float64  `json:"avg_energy"`
	AvgMood        float64  `json:"avg_mood"`
	TotalFood      float64  `json:"total_food"`
	HabitableCells int      `json:"habitable_cells"`
	DangerCells    int      `json:"danger_cells"`
	Weather        string   `json:"weather"`
	ActiveEvents   []string `json:"active_events,omitempty"`
}

// ActiveEffect 活跃持续效果（buff）
type ActiveEffect struct {
	ItemID         uint    `json:"item_id"`
	EffectKey      string  `json:"effect_key"`      // hunger/energy/mood/experience/all
	EffectValue    float64 `json:"effect_value"`     // 每 tick 效果值
	RemainingTicks int     `json:"remaining_ticks"`
}

// ActiveEffectSummary 广播用（给前端展示 buff 图标）
type ActiveEffectSummary struct {
	ItemID    uint   `json:"item_id"`
	Icon      string `json:"icon"`
	Name      string `json:"name"`
	Remaining int    `json:"remaining"`
}

// EntityDiff is the wire format for entity updates.
type EntityDiff struct {
	ID            uint                  `json:"id"`
	Name          string                `json:"name"`
	Emoji         string                `json:"emoji"`
	Hunger        float64               `json:"hunger"`
	Energy        float64               `json:"energy"`
	Mood          float64               `json:"mood"`
	CurrentAction LifeAction            `json:"action"`
	PositionX     float64               `json:"x"`
	PositionY     float64               `json:"y"`
	Age           int                   `json:"age"`
	GrowthStage   string                `json:"growth_stage"`
	Experience    float64               `json:"experience"`
	ActiveEffects []ActiveEffectSummary `json:"active_effects,omitempty"`
}

// EventDiff is the wire format for world events.
type EventDiff struct {
	EntityID   uint    `json:"entity_id"`
	EntityType string  `json:"entity_type"`
	EventType  string  `json:"type"`
	Desc       string  `json:"desc"`
	PositionX  float64 `json:"x"`
	PositionY  float64 `json:"y"`
}

// RelationshipDiff is the wire format for relationship updates.
type RelationshipDiff struct {
	EntityID     uint    `json:"entity_id"`
	TargetID     uint    `json:"target_id"`
	RelationType string  `json:"relation_type"`
	Affinity     float64 `json:"affinity"`
}

// RemovedRelationship represents a dissolved relationship.
type RemovedRelationship struct {
	EntityID uint `json:"entity_id"`
	TargetID uint `json:"target_id"`
}

// TickBroadcast is sent to REST snapshots and WebSocket subscribers.
type TickBroadcast struct {
	Type    string       `json:"type"`
	WorldID string       `json:"world_id"`
	Tick    int64        `json:"tick"`
	Summary WorldSummary `json:"summary"`
	Changes TickChanges  `json:"changes"`
}

// TickChanges contains incremental world updates.
type TickChanges struct {
	Entities             []EntityDiff          `json:"entities,omitempty"`
	Events               []EventDiff           `json:"events,omitempty"`
	RemovedEntityIDs     []uint                `json:"removed_entity_ids,omitempty"`
	Relationships        []RelationshipDiff    `json:"relationships,omitempty"`
	RemovedRelationships []RemovedRelationship `json:"removed_relationships,omitempty"`
	WorldEvents          []WorldEventDiff      `json:"world_events,omitempty"`
}

// SerializeGrid 将 WorldGrid 序列化为 JSON 字符串
func SerializeGrid(grid *WorldGrid) (string, error) {
	if grid == nil {
		return "", nil
	}
	data, err := json.Marshal(grid)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

// DeserializeGrid 从 JSON 字符串反序列化 WorldGrid
func DeserializeGrid(data string) (*WorldGrid, error) {
	if data == "" {
		return nil, nil
	}
	var grid WorldGrid
	if err := json.Unmarshal([]byte(data), &grid); err != nil {
		return nil, err
	}
	return &grid, nil
}

// SerializeActiveEffects 将 ActiveEffect 切片序列化为 JSON 字符串
func SerializeActiveEffects(effects []ActiveEffect) (string, error) {
	if len(effects) == 0 {
		return "", nil
	}
	data, err := json.Marshal(effects)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

// DeserializeActiveEffects 从 JSON 字符串反序列化 ActiveEffect 切片
func DeserializeActiveEffects(data string) ([]ActiveEffect, error) {
	if data == "" {
		return nil, nil
	}
	var effects []ActiveEffect
	if err := json.Unmarshal([]byte(data), &effects); err != nil {
		return nil, err
	}
	return effects, nil
}

// SpeciesPredators 定义物种的捕食关系
// key 为捕食者 emoji，value 为猎物 emoji 列表
var SpeciesPredators = map[string][]string{
	"🐱": {"🐟", "🐦", "🐰"}, // 猫捕食鱼/鸟/兔
	"🐶": {"🐰", "🐦"},       // 狗捕食兔/鸟
}

// IsPredatorOf 检查 predator 是否捕食 prey
func IsPredatorOf(predatorEmoji, preyEmoji string) bool {
	preys, ok := SpeciesPredators[predatorEmoji]
	if !ok {
		return false
	}
	for _, p := range preys {
		if p == preyEmoji {
			return true
		}
	}
	return false
}
