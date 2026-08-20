package model

import "time"

const (
	BattleRoomDraft    = "draft"
	BattleRoomRunning  = "running"
	BattleRoomFinished = "finished"
	BattleSideLeft     = "left"
	BattleSideRight    = "right"
)

// BattleRoom is the server-authoritative PK room and clock anchor.
type BattleRoom struct {
	ID          uint       `gorm:"primarykey" json:"id"`
	LeftUserID  uint       `gorm:"not null;index" json:"left_user_id"`
	RightUserID uint       `gorm:"not null;index" json:"right_user_id"`
	Status      string     `gorm:"size:16;not null;index" json:"status"`
	StartedAt   *time.Time `json:"started_at"`
	EndsAt      *time.Time `gorm:"index" json:"ends_at"`
	WinnerSide  string     `gorm:"size:8" json:"winner_side"`
	EventSeq    uint64     `gorm:"not null;default:0" json:"event_seq"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

// BattleScore holds one side's materialized score for a room.
type BattleScore struct {
	ID        uint      `gorm:"primarykey" json:"id"`
	RoomID    uint      `gorm:"not null;uniqueIndex:idx_battle_room_side" json:"room_id"`
	Side      string    `gorm:"size:8;not null;uniqueIndex:idx_battle_room_side" json:"side"`
	Score     int64     `gorm:"not null;default:0" json:"score"`
	GiftValue int64     `gorm:"not null;default:0" json:"gift_value"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// BattleGiftEvent is the append-only auditable score event.
type BattleGiftEvent struct {
	ID           uint      `gorm:"primarykey" json:"id"`
	RoomID       uint      `gorm:"not null;uniqueIndex:idx_battle_event_seq" json:"room_id"`
	EventSeq     uint64    `gorm:"not null;uniqueIndex:idx_battle_event_seq" json:"event_seq"`
	SenderUserID uint      `gorm:"not null;index" json:"sender_user_id"`
	Side         string    `gorm:"size:8;not null" json:"side"`
	GiftRecordID uint      `gorm:"not null;index" json:"gift_record_id"`
	GiftID       uint      `gorm:"not null;index" json:"gift_id"`
	Quantity     int       `gorm:"not null" json:"quantity"`
	ScoreDelta   int64     `gorm:"not null" json:"score_delta"`
	CreatedAt    time.Time `json:"created_at"`
}

// BattleIdempotencyKey prevents a client retry from creating a second charge.
type BattleIdempotencyKey struct {
	ID           uint      `gorm:"primarykey" json:"id"`
	RoomID       uint      `gorm:"not null;uniqueIndex:idx_battle_idempotency" json:"room_id"`
	SenderUserID uint      `gorm:"not null;uniqueIndex:idx_battle_idempotency" json:"sender_user_id"`
	RequestID    string    `gorm:"size:64;not null;uniqueIndex:idx_battle_idempotency" json:"request_id"`
	EventID      uint      `gorm:"not null" json:"event_id"`
	CreatedAt    time.Time `json:"created_at"`
}
