package model

import "time"

// LLMManagedModel is the durable ownership and write-intent ledger. Never expose it as an API DTO.
type LLMManagedModel struct {
	ID             uint   `gorm:"primarykey"`
	OwnerID        uint   `gorm:"not null;uniqueIndex:idx_llm_owner_agent"`
	AgentID        string `gorm:"size:128;not null;uniqueIndex:idx_llm_owner_agent"`
	ManagedName    string `gorm:"size:128;not null;uniqueIndex"`
	EndpointScope  string `gorm:"size:64;not null;index"`
	BaseModel      string `gorm:"size:256;not null"`
	RequestID      string `gorm:"size:128;not null"`
	IntentHash     string `gorm:"size:64;not null"`
	RequestHashes  string `gorm:"type:longtext"` // Retain prior IDs so delayed retries cannot overwrite newer intents.
	Intent         string `gorm:"size:16;not null"`
	Prompt         string `gorm:"type:longtext"`
	CardSnapshot   string `gorm:"type:longtext"`
	BaseEvidence   string `gorm:"type:longtext"`
	State          string `gorm:"size:16;not null;index"`
	Message        string `gorm:"size:256"`
	BindingApplied bool
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

func (LLMManagedModel) TableName() string { return "llm_managed_models" }
