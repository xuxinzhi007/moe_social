package model

import "time"

// GameWorldState 会话世界状态独立字段表（从 flags_json 拆分，双写架构）。
type GameWorldState struct {
	ID            uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	SessionID     uint      `gorm:"uniqueIndex;not null" json:"session_id"`
	PlayerFocus   string    `gorm:"type:varchar(128);not null;default:''" json:"player_focus"`
	PlayerPosture string    `gorm:"type:varchar(64);not null;default:''" json:"player_posture"`
	WorldMood     string    `gorm:"type:varchar(256);not null;default:''" json:"world_mood"`
	StoryPhase    int       `gorm:"not null;default:0" json:"story_phase"`
	TurnCount     int       `gorm:"not null;default:0" json:"turn_count"`
	LastTalkNpc   string    `gorm:"type:varchar(64);not null;default:''" json:"last_talk_npc"`
	InDialogue    bool      `gorm:"not null;default:false" json:"in_dialogue"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

func (GameWorldState) TableName() string { return "game_world_states" }

// GameDiscoveredItem 玩家已发现物品（从 flags_json.discovered 拆分）。
type GameDiscoveredItem struct {
	SessionID uint      `gorm:"primaryKey" json:"session_id"`
	ItemName  string    `gorm:"type:varchar(128);primaryKey" json:"item_name"`
	CreatedAt time.Time `json:"created_at"`
}

func (GameDiscoveredItem) TableName() string { return "game_discovered_items" }

// GameVisitedScene 玩家已访问场景（从 flags_json.visited_scenes 拆分）。
type GameVisitedScene struct {
	SessionID      uint      `gorm:"primaryKey" json:"session_id"`
	SceneID        uint      `gorm:"primaryKey" json:"scene_id"`
	VisitCount     int       `gorm:"not null;default:1" json:"visit_count"`
	FirstVisitedAt time.Time `json:"first_visited_at"`
	LastVisitedAt  time.Time `json:"last_visited_at"`
}

func (GameVisitedScene) TableName() string { return "game_visited_scenes" }

// GameNpcActivity NPC 当前活动（从 flags_json.npc_activity 拆分）。
type GameNpcActivity struct {
	SessionID uint      `gorm:"primaryKey" json:"session_id"`
	NpcID     uint      `gorm:"primaryKey" json:"npc_id"`
	Activity  string    `gorm:"type:varchar(256);not null;default:''" json:"activity"`
	SceneName string    `gorm:"type:varchar(128);not null;default:''" json:"scene_name"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (GameNpcActivity) TableName() string { return "game_npc_activities" }
