package moebridge

import (
	adminv1 "backend/api/admin/v1"
	postv1 "backend/api/post/v1"
	"backend/internal/legacy/types"
)

func RuntimeItemFromRPC(item *adminv1.MoeAgentRuntimeItem) types.MoeAgentRuntimeItem {
	if item == nil {
		return types.MoeAgentRuntimeItem{}
	}
	return types.MoeAgentRuntimeItem{
		AgentKey:          item.GetAgentKey(),
		DisplayName:       item.GetDisplayName(),
		BotUserId:         item.GetBotUserId(),
		CapabilityTier:    item.GetCapabilityTier(),
		ModelName:         item.GetModelName(),
		ProviderProfileId: item.GetProviderProfileId(),
		ToolsEnabled:      item.GetToolsEnabled(),
		PostQuotaDaily:    int(item.GetPostQuotaDaily()),
		PostsToday:        int(item.GetPostsToday()),
		Enabled:           item.GetEnabled(),
		LastRunAt:         item.GetLastRunAt(),
		LastPostId:        item.GetLastPostId(),
		PostScheduleMode:  item.GetPostScheduleMode(),
		ScheduleCron:      item.GetScheduleCron(),
		NextRunAt:         item.GetNextRunAt(),
		SystemPrompt:      item.GetSystemPrompt(),
		PostRules:         item.GetPostRules(),
		ForbiddenTags:     item.GetForbiddenTags(),
		PreferredTags:     item.GetPreferredTags(),
	}
}

func BrainDataFromRPC(d *adminv1.AdminGetMoeBrainResp) types.AdminGetMoeBrainData {
	if d == nil {
		return types.AdminGetMoeBrainData{}
	}
	out := types.AdminGetMoeBrainData{
		AgentKey:      d.GetAgentKey(),
		DisplayName:   d.GetDisplayName(),
		BotUserId:     d.GetBotUserId(),
		ForbiddenTags: d.GetForbiddenTags(),
		PreferredTags: d.GetPreferredTags(),
	}
	for _, t := range d.GetTagStats() {
		out.TagStats = append(out.TagStats, types.MoeBrainTagStat{Tag: t.GetTag(), Count: int(t.GetCount())})
	}
	for _, e := range d.GetEpisodes() {
		out.Episodes = append(out.Episodes, types.MoeBrainEpisodeItem{
			Id:            uint(e.GetId()),
			PostId:        e.GetPostId(),
			Content:       e.GetContent(),
			Tags:          e.GetTags(),
			MoodTag:       e.GetMoodTag(),
			StyleScore:    int(e.GetStyleScore()),
			QualityScore:  int(e.GetQualityScore()),
			Approved:      e.GetApproved(),
			RevisionCount: int(e.GetRevisionCount()),
			MemoryKey:     e.GetMemoryKey(),
			Source:        e.GetSource(),
			CreatedAt:     e.GetCreatedAt(),
		})
	}
	for _, m := range d.GetMemories() {
		out.Memories = append(out.Memories, types.MoeBrainMemoryItem{
			Key:        m.GetKey(),
			Value:      m.GetValue(),
			MemoryType: m.GetMemoryType(),
			UpdatedAt:  m.GetUpdatedAt(),
		})
	}
	if gm := d.GetGenerationMeta(); gm != nil {
		out.GenerationMeta = types.MoeBrainGenerationMeta{
			PostUsesToolMemory: gm.GetPostUsesToolMemory(),
			MemoriesSynced:     int(gm.GetMemoriesSynced()),
			EpisodesInPrompt:   int(gm.GetEpisodesInPrompt()),
			PromptMemoryLines:  int(gm.GetPromptMemoryLines()),
			PromptPreview:      gm.GetPromptPreview(),
			PromptEstTokens:    int(gm.GetPromptEstTokens()),
			ContextLimit:       int(gm.GetContextLimit()),
			ContextUsedPct:     gm.GetContextUsedPct(),
			Note:               gm.GetNote(),
		}
	}
	out.StabilityScore = int(d.GetStabilityScore())
	out.StabilityDelta = int(d.GetStabilityDelta())
	out.AvgEpisodeQuality = int(d.GetAvgEpisodeQuality())
	return out
}

func RefineResultFromRPC(d *adminv1.AdminRefineMoeBrainEpisodeResp) types.AdminRefineMoeBrainEpisodeData {
	if d == nil {
		return types.AdminRefineMoeBrainEpisodeData{}
	}
	return types.AdminRefineMoeBrainEpisodeData{
		EpisodeId:     uint(d.GetEpisodeId()),
		Ok:            d.GetOk(),
		Approved:      d.GetApproved(),
		QualityScore:  int(d.GetQualityScore()),
		BeforeContent: d.GetBeforeContent(),
		AfterContent:  d.GetAfterContent(),
		Attempts:      int(d.GetAttempts()),
		Detail:        d.GetDetail(),
	}
}

func ToolStatsFromRPC(d *adminv1.AdminGetMoeToolStatsResp) types.AdminMoeToolStatsData {
	if d == nil {
		return types.AdminMoeToolStatsData{}
	}
	out := types.AdminMoeToolStatsData{
		TotalCalls:   d.GetTotalCalls(),
		SuccessCalls: d.GetSuccessCalls(),
		FailedCalls:  d.GetFailedCalls(),
	}
	for _, row := range d.GetByTool() {
		out.ByTool = append(out.ByTool, types.AdminMoeToolStatRow{
			Tool:         row.GetTool(),
			TotalCalls:   row.GetTotalCalls(),
			SuccessCalls: row.GetSuccessCalls(),
			FailedCalls:  row.GetFailedCalls(),
		})
	}
	for _, row := range d.GetByDay() {
		out.ByDay = append(out.ByDay, types.AdminMoeToolDayStat{
			Date:         row.GetDate(),
			TotalCalls:   row.GetTotalCalls(),
			SuccessCalls: row.GetSuccessCalls(),
		})
	}
	return out
}

func ToolCallsFromRPC(d *adminv1.AdminListMoeToolCallsResp) types.AdminListMoeToolCallsData {
	if d == nil {
		return types.AdminListMoeToolCallsData{}
	}
	out := types.AdminListMoeToolCallsData{Total: d.GetTotal()}
	for _, row := range d.GetItems() {
		out.Items = append(out.Items, types.AdminMoeToolCallItem{
			Id:               row.GetId(),
			Tool:             row.GetTool(),
			ActorUserId:      row.GetActorUserId(),
			AgentKey:         row.GetAgentKey(),
			Ok:               row.GetOk(),
			ErrorMsg:         row.GetErrorMsg(),
			LatencyMs:        int(row.GetLatencyMs()),
			Source:           row.GetSource(),
			ArgumentsPreview: row.GetArgumentsPreview(),
			CreatedAt:        row.GetCreatedAt(),
		})
	}
	return out
}

func PipelineDataFromSuper(d *adminv1.AdminGetMoeBrainPipelineResp) types.AdminGetMoeBrainPipelineData {
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
	data.Running = d.GetRunning()
	data.CurrentPhase = d.GetCurrentPhase()
	data.RunStartedAt = d.GetRunStartedAt()
	data.ActiveStepKey = d.GetActiveStepKey()
	return data
}

func SearchPostsFromRPC(d *postv1.MoeSearchPostsReply) types.SearchPostsData {
	if d == nil {
		return types.SearchPostsData{}
	}
	out := types.SearchPostsData{Total: int(d.GetTotal())}
	for _, h := range d.GetItems() {
		out.Items = append(out.Items, types.SearchPostHit{
			PostId:      h.GetPostId(),
			UserId:      h.GetUserId(),
			UserName:    h.GetUserName(),
			Content:     h.GetContent(),
			Snippet:     h.GetSnippet(),
			MoodTag:     h.GetMoodTag(),
			Likes:       int(h.GetLikes()),
			Comments:    int(h.GetComments()),
			CreatedAt:   h.GetCreatedAt(),
			Score:       h.GetScore(),
			ScoreReason: h.GetScoreReason(),
		})
	}
	return out
}
