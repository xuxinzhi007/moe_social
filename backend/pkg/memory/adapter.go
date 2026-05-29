package memory

import (
	"strings"
	"time"

	llmv1 "backend/api/llm/v1"
)

// RecordFromLLMV1 将 llm.v1 记忆转为域模型。
func RecordFromLLMV1(m *llmv1.UserMemory) Record {
	if m == nil {
		return Record{}
	}
	updated, _ := time.ParseInLocation("2006-01-02 15:04:05", strings.TrimSpace(m.UpdatedAt), time.Local)
	if updated.IsZero() {
		updated, _ = time.Parse(time.RFC3339, strings.TrimSpace(m.UpdatedAt))
	}
	return Record{
		ID:          m.Id,
		UserID:      m.UserId,
		Key:         m.Key,
		Value:       m.Value,
		MemoryType:  m.MemoryType,
		Confidence:  m.Confidence,
		Source:      m.Source,
		SourceMsgID: m.SourceMsgId,
		SessionID:   m.SessionId,
		UpdatedAt:   updated,
	}
}

// RecordsFromLLMV1 批量转换 llm.v1 记忆。
func RecordsFromLLMV1(list []*llmv1.UserMemory) []Record {
	out := make([]Record, 0, len(list))
	for _, m := range list {
		if m == nil {
			continue
		}
		out = append(out, RecordFromLLMV1(m))
	}
	return out
}
