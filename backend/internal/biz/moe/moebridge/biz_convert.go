package moebridge

import (
	"strconv"

	moebiz "backend/internal/biz/moe"
	"backend/internal/legacy/types"
	"backend/model"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/runtime"
)

func RuntimeItemFromModel(rt model.MoeAgentRuntime) types.MoeAgentRuntimeItem {
	item := runtime.ItemFromModel(rt)
	return types.MoeAgentRuntimeItem{
		AgentKey:          item.AgentKey,
		DisplayName:       item.DisplayName,
		BotUserId:         item.BotUserId,
		CapabilityTier:    item.CapabilityTier,
		ModelName:         item.ModelName,
		ProviderProfileId: item.ProviderProfileId,
		ToolsEnabled:      item.ToolsEnabled,
		PostQuotaDaily:    item.PostQuotaDaily,
		PostsToday:        item.PostsToday,
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

func PipelineDataFromBiz(snap moebiz.PipelineSnapshot) types.AdminGetMoeBrainPipelineData {
	data := types.AdminGetMoeBrainPipelineData{
		AgentKey:        snap.AgentKey,
		Ok:              snap.OK,
		Detail:          snap.Detail,
		PostId:          snap.PostID,
		TotalDurationMs: snap.TotalDurationMS,
		Steps:           make([]types.MoePipelineStepItem, 0, len(snap.Steps)),
	}
	if snap.HasRun {
		data.RunAt = snap.RunAt.Format("2006-01-02 15:04:05")
	}
	m := snap.Metrics
	if m.NumCPU != 0 || m.ProcAllocMB != 0 || m.InferenceOnline || m.GpuNote != "" {
		data.HostMetrics = types.MoeHostMetrics{
			ProcAllocMB:      m.ProcAllocMB,
			ProcSysMB:        m.ProcSysMB,
			NumCPU:           m.NumCPU,
			NumGoroutine:     m.NumGoroutine,
			InferenceOnline:  m.InferenceOnline,
			InferenceBaseURL: m.InferenceBaseURL,
			InferenceModels:  m.InferenceModels,
			GpuNote:          m.GpuNote,
		}
	}
	for _, a := range snap.GenerateAttempts {
		data.GenerateAttempts = append(data.GenerateAttempts, types.MoeGenAttemptItem{
			Attempt: a.Attempt,
			Outcome: a.Outcome,
			Snippet: a.Snippet,
			Note:    a.Note,
		})
	}
	for _, s := range snap.Steps {
		data.Steps = append(data.Steps, types.MoePipelineStepItem{
			Key:        s.Key,
			Label:      s.Label,
			Status:     s.Status,
			Detail:     s.Detail,
			DurationMs: s.DurationMS,
		})
	}
	for _, t := range snap.ToolsInvoked {
		data.ToolsInvoked = append(data.ToolsInvoked, types.MoePipelineToolInvokeItem{
			Tool:      t.Tool,
			Ok:        t.Ok,
			LatencyMs: t.LatencyMs,
			CreatedAt: t.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	data.StabilityScore = snap.StabilityScore
	data.StabilityDelta = snap.StabilityDelta
	data.RunFeedback = snap.RunFeedback
	data.Running = snap.Running
	data.CurrentPhase = snap.CurrentPhase
	data.ActiveStepKey = snap.ActiveStepKey
	if snap.Running && !snap.RunStartedAt.IsZero() {
		data.RunStartedAt = snap.RunStartedAt.Format("2006-01-02 15:04:05")
	}
	return data
}

func BrainDataFromSnapshot(s *brain.Snapshot) types.AdminGetMoeBrainData {
	if s == nil {
		return types.AdminGetMoeBrainData{}
	}
	out := types.AdminGetMoeBrainData{
		AgentKey:      s.AgentKey,
		DisplayName:   s.DisplayName,
		BotUserId:     strconv.FormatUint(uint64(s.BotUserID), 10),
		ForbiddenTags: s.ForbiddenTags,
		PreferredTags: s.PreferredTags,
	}
	for _, t := range s.TagStats {
		out.TagStats = append(out.TagStats, types.MoeBrainTagStat{Tag: t.Tag, Count: t.Count})
	}
	for _, e := range s.Episodes {
		out.Episodes = append(out.Episodes, types.MoeBrainEpisodeItem{
			Id:            e.ID,
			PostId:        e.PostID,
			Content:       e.Content,
			Tags:          e.Tags,
			MoodTag:       e.MoodTag,
			StyleScore:    e.StyleScore,
			QualityScore:  e.QualityScore,
			Approved:      e.Approved,
			RevisionCount: e.RevisionCount,
			MemoryKey:     e.MemoryKey,
			Source:        e.Source,
			CreatedAt:     e.CreatedAt,
		})
	}
	for _, m := range s.Memories {
		out.Memories = append(out.Memories, types.MoeBrainMemoryItem{
			Key:        m.Key,
			Value:      m.Value,
			MemoryType: m.MemoryType,
			UpdatedAt:  m.UpdatedAt,
		})
	}
	gm := s.GenerationMeta
	out.GenerationMeta = types.MoeBrainGenerationMeta{
		PostUsesToolMemory: gm.PostUsesToolMemory,
		MemoriesSynced:     gm.MemoriesSynced,
		EpisodesInPrompt:   gm.EpisodesInPrompt,
		PromptMemoryLines:  gm.PromptMemoryLines,
		PromptPreview:      gm.PromptPreview,
		PromptEstTokens:    gm.PromptEstTokens,
		ContextLimit:       gm.ContextLimit,
		ContextUsedPct:     gm.ContextUsedPct,
		Note:               gm.Note,
	}
	out.StabilityScore = s.StabilityScore
	out.StabilityDelta = s.StabilityDelta
	if len(s.Episodes) > 0 {
		sum := 0
		for _, e := range s.Episodes {
			sum += e.QualityScore
		}
		out.AvgEpisodeQuality = sum / len(s.Episodes)
	}
	return out
}

func ToolStatsDataFromBiz(s moebiz.ToolStatsResult) types.AdminMoeToolStatsData {
	out := types.AdminMoeToolStatsData{
		TotalCalls:   s.TotalCalls,
		SuccessCalls: s.SuccessCalls,
		FailedCalls:  s.FailedCalls,
	}
	for _, row := range s.ByTool {
		out.ByTool = append(out.ByTool, types.AdminMoeToolStatRow{
			Tool:         row.Tool,
			TotalCalls:   row.TotalCalls,
			SuccessCalls: row.SuccessCalls,
			FailedCalls:  row.FailedCalls,
		})
	}
	for _, row := range s.ByDay {
		out.ByDay = append(out.ByDay, types.AdminMoeToolDayStat{
			Date:         row.Date,
			TotalCalls:   row.TotalCalls,
			SuccessCalls: row.SuccessCalls,
		})
	}
	return out
}

func ToolCallsDataFromBiz(rows []moebiz.ToolCallRow, total int64) types.AdminListMoeToolCallsData {
	out := types.AdminListMoeToolCallsData{Total: total}
	for _, row := range rows {
		out.Items = append(out.Items, types.AdminMoeToolCallItem{
			Id:               strconv.FormatUint(uint64(row.ID), 10),
			Tool:             row.Tool,
			ActorUserId:      strconv.FormatUint(uint64(row.ActorUserID), 10),
			AgentKey:         row.AgentKey,
			Ok:               row.Ok,
			ErrorMsg:         row.ErrorMsg,
			LatencyMs:        row.LatencyMs,
			Source:           row.Source,
			ArgumentsPreview: row.ArgumentsPreview,
			CreatedAt:        row.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return out
}

func RefineDataFromBiz(r brain.RefineResult) types.AdminRefineMoeBrainEpisodeData {
	return types.AdminRefineMoeBrainEpisodeData{
		EpisodeId:     r.EpisodeID,
		Ok:            r.OK,
		Approved:      r.Approved,
		QualityScore:  r.QualityScore,
		BeforeContent: r.BeforeContent,
		AfterContent:  r.AfterContent,
		Attempts:      r.Attempts,
		Detail:        r.Detail,
	}
}
