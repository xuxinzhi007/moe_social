package runtime

import (
	"strconv"

	"backend/model"
)

// AdminRuntimeItem 管理后台列表项（与 API types 字段对齐，由 logic 层拷贝）。
type AdminRuntimeItem struct {
	AgentKey          string
	DisplayName       string
	BotUserId         string
	CapabilityTier    string
	ModelName         string
	ProviderProfileId string
	ToolsEnabled      bool
	PostQuotaDaily    int
	PostsToday        int
	Enabled           bool
	LastRunAt         string
	LastPostId        string
	PostScheduleMode  string
	ScheduleCron      string
	NextRunAt         string
	SystemPrompt      string
	PostRules         string
	ForbiddenTags     string
	PreferredTags     string
}

func ItemFromModel(rt model.MoeAgentRuntime) AdminRuntimeItem {
	item := AdminRuntimeItem{
		AgentKey:          rt.AgentKey,
		DisplayName:       rt.DisplayName,
		BotUserId:         strconv.FormatUint(uint64(rt.BotUserID), 10),
		CapabilityTier:    rt.CapabilityTier,
		ModelName:         rt.ModelName,
		ProviderProfileId: rt.ProviderProfileID,
		ToolsEnabled:      rt.ToolsEnabled,
		PostQuotaDaily:    rt.PostQuotaDaily,
		PostsToday:        rt.PostsToday,
		Enabled:           rt.Enabled,
		LastPostId:        rt.LastPostID,
		PostScheduleMode:  NormalizeScheduleMode(rt.PostScheduleMode),
		ScheduleCron:      rt.ScheduleCron,
		SystemPrompt:      rt.SystemPrompt,
		PostRules:         rt.PostRules,
		ForbiddenTags:     rt.ForbiddenTags,
		PreferredTags:     rt.PreferredTags,
	}
	if rt.LastRunAt != nil {
		item.LastRunAt = rt.LastRunAt.Format("2006-01-02 15:04:05")
	}
	if rt.NextRunAt != nil {
		item.NextRunAt = rt.NextRunAt.Format("2006-01-02 15:04:05")
	}
	return item
}
