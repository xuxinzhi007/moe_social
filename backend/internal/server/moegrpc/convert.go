package moegrpc

import (
	"strconv"

	moebiz "backend/internal/biz/moe"
	moev1pb "backend/api/moe/v1"
	"backend/model"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/runtime"
)

func runtimeToProto(rt model.MoeAgentRuntime) *moev1pb.AgentRuntime {
	item := runtime.ItemFromModel(rt)
	return &moev1pb.AgentRuntime{
		AgentKey:          item.AgentKey,
		DisplayName:       item.DisplayName,
		BotUserId:         item.BotUserId,
		CapabilityTier:    item.CapabilityTier,
		ModelName:         item.ModelName,
		ProviderProfileId: item.ProviderProfileId,
		ToolsEnabled:      item.ToolsEnabled,
		PostQuotaDaily:    int32(item.PostQuotaDaily),
		PostsToday:        int32(item.PostsToday),
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

func pipelineToProto(snap moebiz.PipelineSnapshot) *moev1pb.GetBrainPipelineReply {
	out := &moev1pb.GetBrainPipelineReply{
		AgentKey:        snap.AgentKey,
		Ok:              snap.OK,
		Detail:          snap.Detail,
		PostId:          snap.PostID,
		TotalDurationMs: snap.TotalDurationMS,
		Steps:           make([]*moev1pb.MoePipelineStep, 0, len(snap.Steps)),
	}
	if snap.HasRun {
		out.RunAt = snap.RunAt.Format("2006-01-02 15:04:05")
	}
	m := snap.Metrics
	if m.NumCPU != 0 || m.ProcAllocMB != 0 || m.InferenceOnline || m.GpuNote != "" {
		out.HostMetrics = &moev1pb.MoeHostMetrics{
			ProcAllocMb:      m.ProcAllocMB,
			ProcSysMb:        m.ProcSysMB,
			NumCpu:           int32(m.NumCPU),
			NumGoroutine:     int32(m.NumGoroutine),
			InferenceOnline:  m.InferenceOnline,
			InferenceBaseUrl: m.InferenceBaseURL,
			InferenceModels:  int32(m.InferenceModels),
			GpuNote:          m.GpuNote,
		}
	}
	for _, s := range snap.Steps {
		out.Steps = append(out.Steps, &moev1pb.MoePipelineStep{
			Key:        s.Key,
			Label:      s.Label,
			Status:     s.Status,
			Detail:     s.Detail,
			DurationMs: s.DurationMS,
		})
	}
	return out
}

func brainToProto(s *brain.Snapshot) *moev1pb.GetBrainSnapshotReply {
	if s == nil {
		return &moev1pb.GetBrainSnapshotReply{}
	}
	out := &moev1pb.GetBrainSnapshotReply{
		AgentKey:      s.AgentKey,
		DisplayName:   s.DisplayName,
		BotUserId:     strconv.FormatUint(uint64(s.BotUserID), 10),
		ForbiddenTags: s.ForbiddenTags,
		PreferredTags: s.PreferredTags,
	}
	for _, t := range s.TagStats {
		out.TagStats = append(out.TagStats, &moev1pb.BrainTagStat{Tag: t.Tag, Count: int32(t.Count)})
	}
	for _, e := range s.Episodes {
		out.Episodes = append(out.Episodes, &moev1pb.BrainEpisode{
			Id:            uint64(e.ID),
			PostId:        e.PostID,
			Content:       e.Content,
			Tags:          e.Tags,
			MoodTag:       e.MoodTag,
			StyleScore:    int32(e.StyleScore),
			QualityScore:  int32(e.QualityScore),
			Approved:      e.Approved,
			RevisionCount: int32(e.RevisionCount),
			MemoryKey:     e.MemoryKey,
			Source:        e.Source,
			CreatedAt:     e.CreatedAt,
		})
	}
	for _, m := range s.Memories {
		out.Memories = append(out.Memories, &moev1pb.BrainMemory{
			Key:        m.Key,
			Value:      m.Value,
			MemoryType: m.MemoryType,
			UpdatedAt:  m.UpdatedAt,
		})
	}
	gm := s.GenerationMeta
	out.GenerationMeta = &moev1pb.BrainGenerationMeta{
		PostUsesToolMemory: gm.PostUsesToolMemory,
		MemoriesSynced:     int32(gm.MemoriesSynced),
		EpisodesInPrompt:   int32(gm.EpisodesInPrompt),
		PromptMemoryLines:  int32(gm.PromptMemoryLines),
		PromptPreview:      gm.PromptPreview,
		Note:               gm.Note,
		PromptEstTokens:    int32(gm.PromptEstTokens),
		ContextLimit:       int32(gm.ContextLimit),
		ContextUsedPct:     gm.ContextUsedPct,
	}
	return out
}

func refineToProto(r brain.RefineResult) *moev1pb.RefineBrainEpisodeReply {
	return &moev1pb.RefineBrainEpisodeReply{
		EpisodeId:     uint64(r.EpisodeID),
		Ok:            r.OK,
		Approved:      r.Approved,
		QualityScore:  int32(r.QualityScore),
		BeforeContent: r.BeforeContent,
		AfterContent:  r.AfterContent,
		Attempts:      int32(r.Attempts),
		Detail:        r.Detail,
	}
}

func toolStatsToProto(s moebiz.ToolStatsResult) *moev1pb.QueryToolStatsReply {
	out := &moev1pb.QueryToolStatsReply{
		TotalCalls:   s.TotalCalls,
		SuccessCalls: s.SuccessCalls,
		FailedCalls:  s.FailedCalls,
	}
	for _, row := range s.ByTool {
		out.ByTool = append(out.ByTool, &moev1pb.ToolStatRow{
			Tool:         row.Tool,
			TotalCalls:   row.TotalCalls,
			SuccessCalls: row.SuccessCalls,
			FailedCalls:  row.FailedCalls,
		})
	}
	for _, row := range s.ByDay {
		out.ByDay = append(out.ByDay, &moev1pb.ToolDayStat{
			Date:         row.Date,
			TotalCalls:   row.TotalCalls,
			SuccessCalls: row.SuccessCalls,
		})
	}
	return out
}

func toolCallsToProto(rows []moebiz.ToolCallRow, total int64) *moev1pb.ListToolCallsReply {
	out := &moev1pb.ListToolCallsReply{Total: total}
	for _, row := range rows {
		out.Items = append(out.Items, &moev1pb.ToolCallRow{
			Id:               strconv.FormatUint(uint64(row.ID), 10),
			Tool:             row.Tool,
			ActorUserId:      strconv.FormatUint(uint64(row.ActorUserID), 10),
			AgentKey:         row.AgentKey,
			Ok:               row.Ok,
			ErrorMsg:         row.ErrorMsg,
			LatencyMs:        int32(row.LatencyMs),
			Source:           row.Source,
			ArgumentsPreview: row.ArgumentsPreview,
			CreatedAt:        row.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return out
}
