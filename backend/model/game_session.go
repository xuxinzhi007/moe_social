package model

import "time"

// GameSession 玩家文字游戏会话。
type GameSession struct {
	ID             uint      `gorm:"primarykey" json:"id"`
	UserID         uint      `gorm:"not null;index:idx_game_session_user" json:"user_id"`
	SceneID        uint      `gorm:"not null;index" json:"scene_id"`
	GameTime       string    `gorm:"size:64;not null;default:'上午 10:00'" json:"game_time"`
	FlagsJSON      string    `gorm:"type:text" json:"flags_json"`
	NpcFavorJSON   string    `gorm:"type:text" json:"npc_favor_json"`
	IsActive       bool      `gorm:"not null;default:true;index:idx_game_session_user" json:"is_active"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

func (GameSession) TableName() string { return "game_sessions" }

// GameScene 游戏场景（种子或动态生成）。
type GameScene struct {
	ID          uint      `gorm:"primarykey" json:"id"`
	Name        string    `gorm:"size:128;not null;index" json:"name"`
	Description string    `gorm:"type:text" json:"description"`
	ExitsJSON   string    `gorm:"type:text" json:"exits_json"`
	IsSeed      bool      `gorm:"not null;default:false;index" json:"is_seed"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

func (GameScene) TableName() string { return "game_scenes" }

// GameNpc 场景内 NPC。
type GameNpc struct {
	ID              uint      `gorm:"primarykey" json:"id"`
	SceneID         uint      `gorm:"not null;index" json:"scene_id"`
	Name            string    `gorm:"size:64;not null" json:"name"`
	Persona         string    `gorm:"type:text" json:"persona"`
	BaseFavorability int      `gorm:"not null;default:50" json:"base_favorability"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

func (GameNpc) TableName() string { return "game_npcs" }

// GameNpcMemory NPC 对玩家的长期记忆。
type GameNpcMemory struct {
	ID         uint      `gorm:"primarykey" json:"id"`
	PlayerID   uint      `gorm:"not null;index:idx_game_npc_mem_player_npc" json:"player_id"`
	NpcID      uint      `gorm:"not null;index:idx_game_npc_mem_player_npc" json:"npc_id"`
	MemoryText string    `gorm:"type:text;not null" json:"memory_text"`
	Importance int       `gorm:"not null;default:5" json:"importance"`
	CreatedAt  time.Time `json:"created_at"`
}

func (GameNpcMemory) TableName() string { return "game_npc_memories" }

// GameTurnLog 游戏回合审计日志。
type GameTurnLog struct {
	ID              uint      `gorm:"primarykey" json:"id"`
	SessionID       uint      `gorm:"not null;index" json:"session_id"`
	UserAction      string    `gorm:"type:text" json:"user_action"`
	SystemNarrative string    `gorm:"type:longtext" json:"system_narrative"`
	StatePatchJSON  string    `gorm:"type:text" json:"state_patch_json"`
	CreatedAt       time.Time `json:"created_at"`
}

func (GameTurnLog) TableName() string { return "game_turn_logs" }
