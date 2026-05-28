package admingw

import (
	"backend/api/internal/types"
	"backend/rpc/pb/super"
)

func typesAiChatSessionsToSuper(d types.AdminListAiChatSessionsData) *super.AdminListAiChatSessionsResp {
	out := &super.AdminListAiChatSessionsResp{Total: int32(d.Total)}
	for _, item := range d.Items {
		out.Items = append(out.Items, &super.AdminAiChatSessionItem{
			Id: item.Id, UserId: item.UserId, Username: item.Username,
			SessionId: item.SessionId, Model: item.Model,
			MessageCount: int32(item.MessageCount),
			LastMessageAt: item.LastMessageAt, CreatedAt: item.CreatedAt, UpdatedAt: item.UpdatedAt,
		})
	}
	return out
}

func typesAiChatMessagesToSuper(d types.AdminListAiChatMessagesData) *super.AdminListAiChatMessagesResp {
	out := &super.AdminListAiChatMessagesResp{Total: int32(d.Total)}
	for _, item := range d.Items {
		out.Items = append(out.Items, &super.AdminAiChatMessageItem{
			Id: item.Id, UserId: item.UserId, Username: item.Username,
			SessionId: item.SessionId, SourceMsgId: item.SourceMsgId,
			Role: item.Role, Content: item.Content, Model: item.Model, CreatedAt: item.CreatedAt,
		})
	}
	return out
}

func typesAnalyticsOverviewToSuper(d types.AdminAnalyticsOverviewData) *super.AdminAnalyticsOverviewResp {
	out := &super.AdminAnalyticsOverviewResp{
		UserTotal: int32(d.UserTotal), UsersNew_7D: int32(d.UsersNew7d),
		MemoryTotal: int32(d.MemoryTotal), MemoryUsers: int32(d.MemoryUsers),
		MoeToolCalls_7D: int32(d.MoeToolCalls7d), MoeToolSuccessRate: d.MoeToolSuccessRate,
		ChatSessionsTotal: int32(d.ChatSessionsTotal), ChatMessages_7D: int32(d.ChatMessages7d),
	}
	for _, row := range d.UsersByDay {
		out.UsersByDay = append(out.UsersByDay, &super.AdminDayStat{Date: row.Date, Count: int32(row.Count)})
	}
	for _, row := range d.MemoriesByDay {
		out.MemoriesByDay = append(out.MemoriesByDay, &super.AdminDayStat{Date: row.Date, Count: int32(row.Count)})
	}
	for _, row := range d.MoeToolsByDay {
		out.MoeToolsByDay = append(out.MoeToolsByDay, &super.AdminDayStat{Date: row.Date, Count: int32(row.Count)})
	}
	for _, row := range d.ChatMessagesByDay {
		out.ChatMessagesByDay = append(out.ChatMessagesByDay, &super.AdminDayStat{Date: row.Date, Count: int32(row.Count)})
	}
	for _, row := range d.MemoryByType {
		out.MemoryByType = append(out.MemoryByType, &super.AdminMemoryTypeStat{
			MemoryType: row.MemoryType, Count: int32(row.Count),
		})
	}
	return out
}

func typesTopicTagsToSuper(d types.AdminListTopicTagsData) *super.AdminListTopicTagsResp {
	out := &super.AdminListTopicTagsResp{Total: int32(d.Total)}
	for _, item := range d.Items {
		out.Items = append(out.Items, &super.TopicTag{
			Id: item.Id, Name: item.Name, Color: item.Color, CreatedAt: item.CreatedAt,
		})
	}
	return out
}
