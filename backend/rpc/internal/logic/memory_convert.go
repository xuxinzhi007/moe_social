package logic

import (
	"strconv"

	"backend/model"
	"backend/pkg/memory"
)

func recordsFromUserMemoryModels(list []model.UserMemory) []memory.Record {
	out := make([]memory.Record, 0, len(list))
	for _, m := range list {
		out = append(out, memory.Record{
			ID:          strconv.FormatUint(uint64(m.ID), 10),
			UserID:      strconv.FormatUint(uint64(m.UserID), 10),
			Key:         m.Key,
			Value:       m.Value,
			MemoryType:  m.MemoryType,
			Confidence:  m.Confidence,
			Source:      m.Source,
			SourceMsgID: m.SourceMsgID,
			SessionID:   m.SessionID,
			UpdatedAt:   m.UpdatedAt,
		})
	}
	return out
}
