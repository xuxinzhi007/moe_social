package lifebiz

import "time"

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
)

// LifeConfig controls the in-process life engine.
type LifeConfig struct {
	TickInterval   time.Duration
	MaxEntities    int
	WorldName      string
	FlushInterval  time.Duration
	FlushBatchSize int
	GridWidth      int
	GridHeight     int
}

// DefaultConfig returns the default engine config.
func DefaultConfig() LifeConfig {
	return LifeConfig{
		TickInterval:   5 * time.Second,
		MaxEntities:    50,
		WorldName:      "default",
		FlushInterval:  5 * time.Second,
		FlushBatchSize: 100,
		GridWidth:      32,
		GridHeight:     18,
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
	Width  int          `json:"width"`
	Height int          `json:"height"`
	Cells  [][]WorldCell `json:"cells,omitempty"`
}

// WorldSummary provides a compact ecosystem overview for UI and telemetry.
type WorldSummary struct {
	EntityCount    int     `json:"entity_count"`
	AliveCount     int     `json:"alive_count"`
	BirthCount     int     `json:"birth_count"`
	DeathCount     int     `json:"death_count"`
	AvgHunger      float64 `json:"avg_hunger"`
	AvgEnergy      float64 `json:"avg_energy"`
	AvgMood        float64 `json:"avg_mood"`
	TotalFood      float64 `json:"total_food"`
	HabitableCells int     `json:"habitable_cells"`
	DangerCells    int     `json:"danger_cells"`
}

// EntityDiff is the wire format for entity updates.
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

// EventDiff is the wire format for world events.
type EventDiff struct {
	EntityID   uint    `json:"entity_id"`
	EntityType string  `json:"entity_type"`
	EventType  string  `json:"type"`
	Desc       string  `json:"desc"`
	PositionX  float64 `json:"x"`
	PositionY  float64 `json:"y"`
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
	Entities []EntityDiff `json:"entities,omitempty"`
	Events   []EventDiff  `json:"events,omitempty"`
}
