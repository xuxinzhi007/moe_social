package common

import (
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
)

func RpcAdminAiChatSessionToTypes(item *moe.AdminAiChatSessionItem) types.AdminAiChatSessionItem {
	if item == nil {
		return types.AdminAiChatSessionItem{}
	}
	return types.AdminAiChatSessionItem{
		Id:            item.GetId(),
		UserId:        item.GetUserId(),
		Username:      item.GetUsername(),
		SessionId:     item.GetSessionId(),
		Model:         item.GetModel(),
		MessageCount:  int(item.GetMessageCount()),
		LastMessageAt: item.GetLastMessageAt(),
		CreatedAt:     item.GetCreatedAt(),
		UpdatedAt:     item.GetUpdatedAt(),
	}
}

func RpcAdminAiChatMessageToTypes(item *moe.AdminAiChatMessageItem) types.AdminAiChatMessageItem {
	if item == nil {
		return types.AdminAiChatMessageItem{}
	}
	return types.AdminAiChatMessageItem{
		Id:          item.GetId(),
		UserId:      item.GetUserId(),
		Username:    item.GetUsername(),
		SessionId:   item.GetSessionId(),
		SourceMsgId: item.GetSourceMsgId(),
		Role:        item.GetRole(),
		Content:     item.GetContent(),
		Model:       item.GetModel(),
		CreatedAt:   item.GetCreatedAt(),
	}
}

func RpcAdminDayStatsToTypes(rows []*moe.AdminDayStat) []types.AdminDayStat {
	if len(rows) == 0 {
		return nil
	}
	out := make([]types.AdminDayStat, len(rows))
	for i, row := range rows {
		if row == nil {
			continue
		}
		out[i] = types.AdminDayStat{Date: row.GetDate(), Count: int(row.GetCount())}
	}
	return out
}

func RpcAdminAnalyticsOverviewToTypes(data *moe.AdminAnalyticsOverviewResp) types.AdminAnalyticsOverviewData {
	if data == nil {
		return types.AdminAnalyticsOverviewData{}
	}
	out := types.AdminAnalyticsOverviewData{
		UserTotal:          int(data.GetUserTotal()),
		UsersNew7d:         int(data.GetUsersNew_7D()),
		UsersByDay:         RpcAdminDayStatsToTypes(data.GetUsersByDay()),
		MemoryTotal:        int(data.GetMemoryTotal()),
		MemoryUsers:        int(data.GetMemoryUsers()),
		MemoriesByDay:      RpcAdminDayStatsToTypes(data.GetMemoriesByDay()),
		MoeToolCalls7d:     int(data.GetMoeToolCalls_7D()),
		MoeToolSuccessRate: data.GetMoeToolSuccessRate(),
		MoeToolsByDay:      RpcAdminDayStatsToTypes(data.GetMoeToolsByDay()),
		ChatSessionsTotal:  int(data.GetChatSessionsTotal()),
		ChatMessages7d:     int(data.GetChatMessages_7D()),
		ChatMessagesByDay:  RpcAdminDayStatsToTypes(data.GetChatMessagesByDay()),
	}
	if rows := data.GetMemoryByType(); len(rows) > 0 {
		out.MemoryByType = make([]types.AdminMemoryTypeStat, len(rows))
		for i, row := range rows {
			if row == nil {
				continue
			}
			out.MemoryByType[i] = types.AdminMemoryTypeStat{
				MemoryType: row.GetMemoryType(),
				Count:      int(row.GetCount()),
			}
		}
	}
	return out
}

func RpcTopicTagToTypes(item *moe.TopicTag) types.TopicTag {
	if item == nil {
		return types.TopicTag{}
	}
	return types.TopicTag{
		Id:        item.GetId(),
		Name:      item.GetName(),
		Color:     item.GetColor(),
		CreatedAt: item.GetCreatedAt(),
	}
}

func RpcAdminTagDictionaryToTypes(item *moe.AdminTagDictionaryItem) types.AdminTagDictionaryItem {
	if item == nil {
		return types.AdminTagDictionaryItem{}
	}
	return types.AdminTagDictionaryItem{
		Id:        item.GetId(),
		Category:  item.GetCategory(),
		Tag:       item.GetTag(),
		Label:     item.GetLabel(),
		Note:      item.GetNote(),
		SortOrder: int(item.GetSortOrder()),
		Enabled:   item.GetEnabled(),
		CreatedAt: item.GetCreatedAt(),
		UpdatedAt: item.GetUpdatedAt(),
	}
}
