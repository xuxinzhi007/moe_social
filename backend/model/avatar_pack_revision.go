package model

import "time"

// AvatarPackRevision 用户保存的角色包版本快照。
type AvatarPackRevision struct {
	ID            string    `json:"id" gorm:"primaryKey;type:varchar(36)"`
	UserID        string    `json:"user_id" gorm:"type:varchar(36);not null;index:idx_avatar_pack_revision_lookup,priority:1;uniqueIndex:ux_avatar_pack_revision,priority:1"`
	PackID        string    `json:"pack_id" gorm:"type:varchar(128);not null;index:idx_avatar_pack_revision_lookup,priority:2;uniqueIndex:ux_avatar_pack_revision,priority:2"`
	Version       string    `json:"version" gorm:"type:varchar(64);not null;index:idx_avatar_pack_revision_lookup,priority:3;uniqueIndex:ux_avatar_pack_revision,priority:3"`
	ManifestJSON  string    `json:"manifest_json" gorm:"type:json;not null"`
	ArtifactsJSON string    `json:"artifacts_json" gorm:"type:json;not null"`
	CreatedAt     time.Time `json:"created_at" gorm:"autoCreateTime"`
	UpdatedAt     time.Time `json:"updated_at" gorm:"autoUpdateTime"`
}

// TableName 设置表名。
func (AvatarPackRevision) TableName() string {
	return "avatar_pack_revisions"
}
