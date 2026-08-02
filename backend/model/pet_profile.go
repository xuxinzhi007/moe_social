package model

import "time"

// PetProfile 养成宠物档案（每用户一条）。
type PetProfile struct {
	ID             uint      `json:"id" gorm:"primaryKey"`
	UserID         string    `json:"user_id" gorm:"size:64;uniqueIndex;not null"`
	Name           string    `json:"name" gorm:"size:64;not null;default:小萌"`
	Species        string    `json:"species" gorm:"size:32;default:bunny"`
	Hunger         float64   `json:"hunger" gorm:"default:80"`
	Energy         float64   `json:"energy" gorm:"default:80"`
	Mood           float64   `json:"mood" gorm:"default:70"`
	Coins          int       `json:"coins" gorm:"default:100"`
	AgeYears       int       `json:"age_years" gorm:"default:1"`
	Virtue         int       `json:"virtue" gorm:"default:10"` // 德
	Intel          int       `json:"intel" gorm:"default:10"`  // 智
	Sport          int       `json:"sport" gorm:"default:10"`  // 体
	Art            int       `json:"art" gorm:"default:10"`    // 美
	Labor          int       `json:"labor" gorm:"default:10"`  // 劳
	HatID          string    `json:"hat_id" gorm:"size:64"`
	TopID          string    `json:"top_id" gorm:"size:64"`
	BottomID       string    `json:"bottom_id" gorm:"size:64"`
	ShoesID        string    `json:"shoes_id" gorm:"size:64"`
	SceneID        string    `json:"scene_id" gorm:"size:32;default:living"`
	FurnitureJSON  string    `json:"furniture_json" gorm:"type:text"`   // [{id,x,y,scene,rotation}]
	RoomLayoutJSON string    `json:"room_layout_json" gorm:"type:text"` // [{id,scene,x,y,width,height}]
	OutfitJSON     string    `json:"outfit_json" gorm:"type:text"`      // wear_layout: hat/top/bottom/shoes offsets
	SpouseUserID   string    `json:"spouse_user_id" gorm:"size:64"`
	HasBaby        bool      `json:"has_baby" gorm:"default:false"`
	UpdatedAt      time.Time `json:"updated_at"`
	CreatedAt      time.Time `json:"created_at"`
}

func (PetProfile) TableName() string { return "pet_profiles" }

// PetFriendship 养成好友关系。
type PetFriendship struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	UserID    string    `json:"user_id" gorm:"size:64;index;not null"`
	FriendID  string    `json:"friend_id" gorm:"size:64;index;not null"`
	Status    string    `json:"status" gorm:"size:32;default:accepted"` // pending/accepted/married
	CreatedAt time.Time `json:"created_at"`
}

func (PetFriendship) TableName() string { return "pet_friendships" }
