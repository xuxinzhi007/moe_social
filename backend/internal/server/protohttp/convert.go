package protohttp

import (
	"strconv"

	moev1pb "backend/api/moe/v1"
	moebiz "backend/internal/biz/moe"
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
	out.StabilityScore = int32(s.StabilityScore)
	out.StabilityDelta = int32(s.StabilityDelta)
	if len(s.Episodes) > 0 {
		sum := 0
		for _, e := range s.Episodes {
			sum += e.QualityScore
		}
		out.AvgEpisodeQuality = int32(sum / len(s.Episodes))
	}
	return out
}

func graphToProto(v brain.GraphView) *moev1pb.GetBrainGraphReply {
	out := &moev1pb.GetBrainGraphReply{
		AgentKey:      v.AgentKey,
		EpisodeCount:  int32(v.EpisodeCount),
		MemoryCount:   int32(v.MemoryCount),
		TagCount:      int32(v.TagCount),
		Nodes:         make([]*moev1pb.BrainGraphNode, 0, len(v.Nodes)),
		Edges:         make([]*moev1pb.BrainGraphEdge, 0, len(v.Edges)),
	}
	for _, n := range v.Nodes {
		out.Nodes = append(out.Nodes, &moev1pb.BrainGraphNode{
			Id:      n.ID,
			Kind:    n.Kind,
			Label:   n.Label,
			Summary: n.Summary,
			Weight:  int32(n.Weight),
			RefId:   n.RefID,
		})
	}
	for _, e := range v.Edges {
		out.Edges = append(out.Edges, &moev1pb.BrainGraphEdge{
			Id:       e.ID,
			Source:   e.Source,
			Target:   e.Target,
			Relation: e.Relation,
			Weight:   e.Weight,
		})
	}
	return out
}

func rpgToProto(v brain.RpgView) *moev1pb.GetBrainRpgReply {
	out := &moev1pb.GetBrainRpgReply{
		AgentKey:       v.AgentKey,
		Level:          int32(v.Level),
		Xp:             int32(v.XP),
		XpToNext:       int32(v.XPToNext),
		StabilityScore: int32(v.StabilityScore),
		LastDreamAt:    v.LastDreamAt,
		DreamEnabled:   v.DreamEnabled,
		DreamCron:      v.DreamCron,
		NextDreamAt:    v.NextDreamAt,
		AutonomousMindEnabled: v.AutonomousMindEnabled,
		PendingDeleteCount:    int32(v.PendingDeleteCount),
		Stats: &moev1pb.BrainRpgStats{
			TotalFragments: int32(v.Stats.TotalFragments),
			SolidMemories:  int32(v.Stats.SolidMemories),
			PendingTidy:    int32(v.Stats.PendingTidy),
			LockedSkills:   int32(v.Stats.LockedSkills),
			GraphNodes:     int32(v.Stats.GraphNodes),
		},
	}
	for _, sk := range v.Skills {
		out.Skills = append(out.Skills, &moev1pb.BrainRpgSkill{
			Tag:        sk.Tag,
			Label:      sk.Label,
			Level:      int32(sk.Level),
			Locked:     sk.Locked,
			UsageCount: int32(sk.UsageCount),
		})
	}
	for _, f := range v.Fragments {
		out.Fragments = append(out.Fragments, &moev1pb.BrainRpgFragment{
			Id:           uint64(f.ID),
			Kind:         f.Kind,
			Title:        f.Title,
			Status:       f.Status,
			QualityScore: int32(f.QualityScore),
			Approved:     f.Approved,
			CreatedAt:    f.CreatedAt,
			MemoryKey:    f.MemoryKey,
		})
	}
	for _, d := range v.RecentDreams {
		out.RecentDreams = append(out.RecentDreams, &moev1pb.BrainRpgDreamLog{
			Id:       uint64(d.ID),
			RanAt:    d.RanAt,
			Summary:  d.Summary,
			Refined:  int32(d.Refined),
			Merged:   int32(d.Merged),
			Archived: int32(d.Archived),
			XpGained: int32(d.XPGained),
		})
	}
	return out
}

func dreamToProto(agentKey string, r brain.DreamResult) *moev1pb.RunBrainDreamReply {
	return &moev1pb.RunBrainDreamReply{
		AgentKey: agentKey,
		Summary:  r.Summary,
		Refined:  int32(r.Refined),
		Merged:   int32(r.Merged),
		Archived: int32(r.Archived),
		XpGained: int32(r.XPGained),
		Level:    int32(r.Level),
		Xp:       int32(r.XP),
	}
}

func compressToProto(agentKey string, r brain.CompressResult) *moev1pb.CompressBrainMemoriesReply {
	return &moev1pb.CompressBrainMemoriesReply{
		AgentKey:          agentKey,
		MemoryKey:         r.MemoryKey,
		Summary:           r.Summary,
		SourceCount:       int32(r.SourceCount),
		XpGained:          int32(r.XPGained),
		SweptCount:        int32(r.SweptCount),
		MergedClusters:    int32(r.MergedClusters),
		MarkedCount:       int32(r.MarkedCount),
		PendingRemaining:  int32(r.PendingRemaining),
	}
}

func tidyToProto(agentKey string, r brain.TidyResult) *moev1pb.TidyBrainFragmentsReply {
	return &moev1pb.TidyBrainFragmentsReply{
		AgentKey: agentKey,
		Total:    int32(r.Total),
		Approved: int32(r.Approved),
		XpGained: int32(r.XPGained),
	}
}

func presenceToProto(v brain.PresenceView) *moev1pb.GetBrainPresenceReply {
	return &moev1pb.GetBrainPresenceReply{
		AgentKey:        v.AgentKey,
		DisplayName:     v.DisplayName,
		Activity:        v.Activity,
		Mood:            v.Mood,
		Thought:         v.Thought,
		PipelineStep:    v.PipelineStep,
		PipelineRunning: v.PipelineRunning,
		DreamEnabled:    v.DreamEnabled,
		DreamCron:       v.DreamCron,
		NextDreamAt:     v.NextDreamAt,
		Dreaming:        v.Dreaming,
		AutonomousMindEnabled: v.AutonomousMindEnabled,
		ThoughtSource:   v.ThoughtSource,
	}
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
