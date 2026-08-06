package apicomm

import (
	adminv1 "backend/api/admin/v1"
	"backend/internal/legacy/types"
)

func RpcAdminMemoryToTypes(item *adminv1.AdminMemoryItem) types.AdminMemoryItem {
	if item == nil {
		return types.AdminMemoryItem{}
	}
	return types.AdminMemoryItem{
		Id:         item.GetId(),
		UserId:     item.GetUserId(),
		Username:   item.GetUsername(),
		Key:        item.GetKey(),
		Value:      item.GetValue(),
		MemoryType: item.GetMemoryType(),
		Confidence: item.GetConfidence(),
		Source:     item.GetSource(),
		UpdatedAt:  item.GetUpdatedAt(),
	}
}

func RpcAdminMemoryStatsToTypes(stats *adminv1.AdminMemoryStats) types.AdminMemoryStats {
	if stats == nil {
		return types.AdminMemoryStats{}
	}
	out := types.AdminMemoryStats{
		TotalMemories:     int(stats.GetTotalMemories()),
		UsersWithMemories: int(stats.GetUsersWithMemories()),
		TotalFeedbacks:    int(stats.GetTotalFeedbacks()),
		TotalEmbeddings:   int(stats.GetTotalEmbeddings()),
	}
	if rows := stats.GetByType(); len(rows) > 0 {
		out.ByType = make([]types.AdminMemoryTypeStat, len(rows))
		for i, row := range rows {
			out.ByType[i] = types.AdminMemoryTypeStat{
				MemoryType: row.GetMemoryType(),
				Count:      int(row.GetCount()),
			}
		}
	}
	return out
}
