package moebridge

import (
	"backend/api/internal/types"
	"backend/rpc/pb/super"
)

func RuntimeItemFromRPC(item *super.MoeAgentRuntimeItem) types.MoeAgentRuntimeItem {
	if item == nil {
		return types.MoeAgentRuntimeItem{}
	}
	return types.MoeAgentRuntimeItem{
		AgentKey:          item.AgentKey,
		DisplayName:       item.DisplayName,
		BotUserId:         item.BotUserId,
		CapabilityTier:    item.CapabilityTier,
		ModelName:         item.ModelName,
		ProviderProfileId: item.ProviderProfileId,
		ToolsEnabled:      item.ToolsEnabled,
		PostQuotaDaily:    int(item.PostQuotaDaily),
		PostsToday:        int(item.PostsToday),
		Enabled:           item.Enabled,
		LastRunAt:         item.LastRunAt,
		LastPostId:        item.LastPostId,
		PostScheduleMode:  item.PostScheduleMode,
		ScheduleCron:      item.ScheduleCron,
		NextRunAt:         item.NextRunAt,
		SystemPrompt:      item.SystemPrompt,
		PostRules:         item.PostRules,
		ForbiddenTags:     item.ForbiddenTags,
		PreferredTags:     item.PreferredTags,
	}
}

func BrainDataFromRPC(d *super.AdminGetMoeBrainResp) types.AdminGetMoeBrainData {
	if d == nil {
		return types.AdminGetMoeBrainData{}
	}
	out := types.AdminGetMoeBrainData{
		AgentKey:      d.AgentKey,
		DisplayName:   d.DisplayName,
		BotUserId:     d.BotUserId,
		ForbiddenTags: d.ForbiddenTags,
		PreferredTags: d.PreferredTags,
	}
	for _, t := range d.TagStats {
		out.TagStats = append(out.TagStats, types.MoeBrainTagStat{Tag: t.Tag, Count: int(t.Count)})
	}
	for _, e := range d.Episodes {
		out.Episodes = append(out.Episodes, types.MoeBrainEpisodeItem{
			Id:            uint(e.Id),
			PostId:        e.PostId,
			Content:       e.Content,
			Tags:          e.Tags,
			MoodTag:       e.MoodTag,
			StyleScore:    int(e.StyleScore),
			QualityScore:  int(e.QualityScore),
			Approved:      e.Approved,
			RevisionCount: int(e.RevisionCount),
			MemoryKey:     e.MemoryKey,
			Source:        e.Source,
			CreatedAt:     e.CreatedAt,
		})
	}
	for _, m := range d.Memories {
		out.Memories = append(out.Memories, types.MoeBrainMemoryItem{
			Key:        m.Key,
			Value:      m.Value,
			MemoryType: m.MemoryType,
			UpdatedAt:  m.UpdatedAt,
		})
	}
	if gm := d.GenerationMeta; gm != nil {
		out.GenerationMeta = types.MoeBrainGenerationMeta{
			PostUsesToolMemory: gm.PostUsesToolMemory,
			MemoriesSynced:     int(gm.MemoriesSynced),
			EpisodesInPrompt:   int(gm.EpisodesInPrompt),
			PromptMemoryLines:  int(gm.PromptMemoryLines),
			PromptPreview:      gm.PromptPreview,
			PromptEstTokens:    int(gm.PromptEstTokens),
			ContextLimit:       int(gm.ContextLimit),
			ContextUsedPct:     gm.ContextUsedPct,
			Note:               gm.Note,
		}
	}
	out.StabilityScore = int(d.GetStabilityScore())
	out.StabilityDelta = int(d.GetStabilityDelta())
	out.AvgEpisodeQuality = int(d.GetAvgEpisodeQuality())
	return out
}

func RefineResultFromRPC(d *super.AdminRefineMoeBrainEpisodeResp) types.AdminRefineMoeBrainEpisodeData {
	if d == nil {
		return types.AdminRefineMoeBrainEpisodeData{}
	}
	return types.AdminRefineMoeBrainEpisodeData{
		EpisodeId:     uint(d.EpisodeId),
		Ok:            d.Ok,
		Approved:      d.Approved,
		QualityScore:  int(d.QualityScore),
		BeforeContent: d.BeforeContent,
		AfterContent:  d.AfterContent,
		Attempts:      int(d.Attempts),
		Detail:        d.Detail,
	}
}

func ToolStatsFromRPC(d *super.AdminGetMoeToolStatsResp) types.AdminMoeToolStatsData {
	if d == nil {
		return types.AdminMoeToolStatsData{}
	}
	out := types.AdminMoeToolStatsData{
		TotalCalls:   d.TotalCalls,
		SuccessCalls: d.SuccessCalls,
		FailedCalls:  d.FailedCalls,
	}
	for _, row := range d.ByTool {
		out.ByTool = append(out.ByTool, types.AdminMoeToolStatRow{
			Tool:         row.Tool,
			TotalCalls:   row.TotalCalls,
			SuccessCalls: row.SuccessCalls,
			FailedCalls:  row.FailedCalls,
		})
	}
	for _, row := range d.ByDay {
		out.ByDay = append(out.ByDay, types.AdminMoeToolDayStat{
			Date:         row.Date,
			TotalCalls:   row.TotalCalls,
			SuccessCalls: row.SuccessCalls,
		})
	}
	return out
}

func ToolCallsFromRPC(d *super.AdminListMoeToolCallsResp) types.AdminListMoeToolCallsData {
	if d == nil {
		return types.AdminListMoeToolCallsData{}
	}
	out := types.AdminListMoeToolCallsData{Total: d.Total}
	for _, row := range d.Items {
		out.Items = append(out.Items, types.AdminMoeToolCallItem{
			Id:               row.Id,
			Tool:             row.Tool,
			ActorUserId:      row.ActorUserId,
			AgentKey:         row.AgentKey,
			Ok:               row.Ok,
			ErrorMsg:         row.ErrorMsg,
			LatencyMs:        int(row.LatencyMs),
			Source:           row.Source,
			ArgumentsPreview: row.ArgumentsPreview,
			CreatedAt:        row.CreatedAt,
		})
	}
	return out
}

func PipelineDataFromSuper(d *super.AdminGetMoeBrainPipelineResp) types.AdminGetMoeBrainPipelineData {
	if d == nil {
		return types.AdminGetMoeBrainPipelineData{Steps: DefaultPipelineStepTypes()}
	}
	data := types.AdminGetMoeBrainPipelineData{
		AgentKey:        d.GetAgentKey(),
		Ok:              d.GetOk(),
		Detail:          d.GetDetail(),
		PostId:          d.GetPostId(),
		RunAt:           d.GetRunAt(),
		TotalDurationMs: d.GetTotalDurationMs(),
		Steps:           make([]types.MoePipelineStepItem, 0, len(d.GetSteps())),
	}
	if hm := d.GetHostMetrics(); hm != nil {
		data.HostMetrics = types.MoeHostMetrics{
			ProcAllocMB:      hm.GetProcAllocMb(),
			ProcSysMB:        hm.GetProcSysMb(),
			NumCPU:           int(hm.GetNumCpu()),
			NumGoroutine:     int(hm.GetNumGoroutine()),
			InferenceOnline:  hm.GetInferenceOnline(),
			InferenceBaseURL: hm.GetInferenceBaseUrl(),
			InferenceModels:  int(hm.GetInferenceModels()),
			GpuNote:          hm.GetGpuNote(),
		}
	}
	for _, s := range d.GetSteps() {
		if s == nil {
			continue
		}
		data.Steps = append(data.Steps, types.MoePipelineStepItem{
			Key: s.GetKey(), Label: s.GetLabel(), Status: s.GetStatus(),
			Detail: s.GetDetail(), DurationMs: s.GetDurationMs(),
		})
	}
	if len(data.Steps) == 0 {
		data.Steps = DefaultPipelineStepTypes()
	}
	data.StabilityScore = int(d.GetStabilityScore())
	data.StabilityDelta = int(d.GetStabilityDelta())
	data.RunFeedback = d.GetRunFeedback()
	return data
}

func SearchPostsFromRPC(d *super.MoeSearchPostsResp) types.SearchPostsData {
	if d == nil {
		return types.SearchPostsData{}
	}
	out := types.SearchPostsData{Total: int(d.Total)}
	for _, h := range d.Items {
		out.Items = append(out.Items, types.SearchPostHit{
			PostId:      h.PostId,
			UserId:      h.UserId,
			UserName:    h.UserName,
			Content:     h.Content,
			Snippet:     h.Snippet,
			MoodTag:     h.MoodTag,
			Likes:       int(h.Likes),
			Comments:    int(h.Comments),
			CreatedAt:   h.CreatedAt,
			Score:       h.Score,
			ScoreReason: h.ScoreReason,
		})
	}
	return out
}
