package memory

import "time"

// Record 记忆文本库中的一条记录（与传输层 / ORM 解耦）。
type Record struct {
	ID          string
	UserID      string
	Key         string
	Value       string
	MemoryType  string
	Confidence  float64
	Source      string
	SourceMsgID string
	SessionID   string
	UpdatedAt   time.Time
}

// DisplayItem 面向 UI / 注入的展示项。
type DisplayItem struct {
	ID        string `json:"id"`
	Key       string `json:"key"`
	Title     string `json:"title"`
	Content   string `json:"content"`
	Category  string `json:"category"`
	UpdatedAt string `json:"updated_at"`
}

// ProfileSummary 按 memory_type 聚合后的画像摘要。
type ProfileSummary struct {
	MemoryType string  `json:"memory_type"`
	Summary    string  `json:"summary"`
	ItemCount  int     `json:"item_count"`
	Confidence float64 `json:"confidence"`
}

// SearchResult 检索结果。
type SearchResult struct {
	Query string        `json:"query"`
	Items []DisplayItem `json:"items"`
	Total int           `json:"total"`
}
