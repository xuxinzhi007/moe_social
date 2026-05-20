package memory

import (
	"strings"
	"time"

	"backend/rpc/pb/super"
)

// RecordFromSuper 将 RPC 记忆转为域模型。
func RecordFromSuper(m *super.UserMemory) Record {
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

// RecordsFromSuper 批量转换。
func RecordsFromSuper(list []*super.UserMemory) []Record {
	out := make([]Record, 0, len(list))
	for _, m := range list {
		if m == nil {
			continue
		}
		out = append(out, RecordFromSuper(m))
	}
	return out
}
