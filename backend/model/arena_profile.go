package model

import "time"

// ArenaProfile 星辉远征玩家存档（每用户一条）。
type ArenaProfile struct {
	ID              uint      `json:"id" gorm:"primaryKey"`
	UserID          string    `json:"user_id" gorm:"size:64;uniqueIndex;not null"`
	StarCrystals    int       `json:"star_crystals" gorm:"not null;default:6280"`
	TowerFloor      int       `json:"tower_floor" gorm:"not null;default:1"`
	FormationJSON   string    `json:"formation_json" gorm:"type:text"`
	OwnedHeroesJSON string    `json:"owned_heroes_json" gorm:"type:text"`
	DeckJSON        string    `json:"deck_json" gorm:"type:text"`
	ProgressJSON    string    `json:"progress_json" gorm:"type:text"` // buff / 爬塔节点等
	UpdatedAt       time.Time `json:"updated_at"`
	CreatedAt       time.Time `json:"created_at"`
}

// TableName 表名。
func (ArenaProfile) TableName() string { return "arena_profiles" }
