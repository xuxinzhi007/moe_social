package model

import "time"

type AiUserConfig struct {
	ID                       uint      `gorm:"primarykey" json:"id"`
	UserID                   uint      `gorm:"not null;uniqueIndex" json:"user_id"`
	ProviderProfilesJSON     string    `gorm:"type:longtext" json:"provider_profiles_json"`
	AgentsJSON               string    `gorm:"type:longtext" json:"agents_json"`
	LorebooksJSON            string    `gorm:"type:longtext" json:"lorebooks_json"`
	ProviderApiKeysEncrypted string    `gorm:"type:longtext" json:"-"`
	UserPersona              string    `gorm:"type:text" json:"user_persona"`
	PreferencesJSON          string    `gorm:"type:text" json:"preferences_json"`
	CreatedAt                time.Time `json:"created_at"`
	UpdatedAt                time.Time `json:"updated_at"`
}
