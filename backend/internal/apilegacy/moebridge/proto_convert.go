package moebridge

import (
	"strconv"

	moepb "backend/api/moe/v1"
	"backend/internal/legacy/types"
	"backend/model"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/runtime"
)

func RuntimeItemFromProto(item *moepb.AgentRuntime) types.MoeAgentRuntimeItem {
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

func RuntimeModelFromProtoList(items []*moepb.AgentRuntime, agentKey string) *model.MoeAgentRuntime {
	for _, item := range items {
		if item != nil && item.GetAgentKey() == agentKey {
			return &model.MoeAgentRuntime{
				AgentKey:  item.GetAgentKey(),
				ModelName: item.GetModelName(),
			}
		}
	}
	return nil
}

func PipelineDataFromProto(d *moepb.GetBrainPipelineReply) types.AdminGetMoeBrainPipelineData {
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
			Key:        s.GetKey(),
			Label:      s.GetLabel(),
			Status:     s.GetStatus(),
			Detail:     s.GetDetail(),
			DurationMs: s.GetDurationMs(),
		})
	}
	if len(data.Steps) == 0 {
		data.Steps = DefaultPipelineStepTypes()
	}
	return data
}

func BrainDataFromProto(d *moepb.GetBrainSnapshotReply) types.AdminGetMoeBrainData {
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
		if t == nil {
			continue
		}
		out.TagStats = append(out.TagStats, types.MoeBrainTagStat{Tag: t.GetTag(), Count: int(t.GetCount())})
	}
	for _, e := range d.GetEpisodes() {
		if e == nil {
			continue
		}
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
		if m == nil {
			continue
		}
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
	return out
}

func RefineResultFromProto(d *moepb.RefineBrainEpisodeReply) types.AdminRefineMoeBrainEpisodeData {
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

func ToolStatsFromProto(d *moepb.QueryToolStatsReply) types.AdminMoeToolStatsData {
	if d == nil {
		return types.AdminMoeToolStatsData{}
	}
	out := types.AdminMoeToolStatsData{
		TotalCalls:   d.GetTotalCalls(),
		SuccessCalls: d.GetSuccessCalls(),
		FailedCalls:  d.GetFailedCalls(),
	}
	for _, row := range d.GetByTool() {
		if row == nil {
			continue
		}
		out.ByTool = append(out.ByTool, types.AdminMoeToolStatRow{
			Tool:         row.GetTool(),
			TotalCalls:   row.GetTotalCalls(),
			SuccessCalls: row.GetSuccessCalls(),
			FailedCalls:  row.GetFailedCalls(),
		})
	}
	for _, row := range d.GetByDay() {
		if row == nil {
			continue
		}
		out.ByDay = append(out.ByDay, types.AdminMoeToolDayStat{
			Date:         row.GetDate(),
			TotalCalls:   row.GetTotalCalls(),
			SuccessCalls: row.GetSuccessCalls(),
		})
	}
	return out
}

func ToolCallsFromProto(d *moepb.ListToolCallsReply) types.AdminListMoeToolCallsData {
	if d == nil {
		return types.AdminListMoeToolCallsData{}
	}
	out := types.AdminListMoeToolCallsData{Total: d.GetTotal()}
	for _, row := range d.GetItems() {
		if row == nil {
			continue
		}
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

func CurateDataFromProto(d *moepb.CurateBrainReply) types.AdminCurateMoeBrainData {
	if d == nil {
		return types.AdminCurateMoeBrainData{}
	}
	out := types.AdminCurateMoeBrainData{
		AgentKey: d.GetAgentKey(),
		Total:    int(d.GetTotal()),
		Approved: int(d.GetApproved()),
	}
	for _, r := range d.GetResults() {
		out.Results = append(out.Results, RefineResultFromProto(r))
	}
	return out
}

// RunResult 试跑结果（biz / v1 / super 统一）。
type RunResult struct {
	AgentKey string
	OK       bool
	Detail   string
	PostID   string
}

func RunResultFromBiz(r runtime.RunOnceResult) RunResult {
	return RunResult{
		AgentKey: r.AgentKey,
		OK:       r.OK,
		Detail:   r.Detail,
		PostID:   r.PostID,
	}
}

func RunResultFromProto(d *moepb.RunAgentOnceReply) RunResult {
	if d == nil {
		return RunResult{}
	}
	return RunResult{
		AgentKey: d.GetAgentKey(),
		OK:       d.GetOk(),
		Detail:   d.GetDetail(),
		PostID:   d.GetPostId(),
	}
}

func BrainSnapshotFromProto(d *moepb.GetBrainSnapshotReply) *brain.Snapshot {
	if d == nil {
		return nil
	}
	s := &brain.Snapshot{
		AgentKey:      d.GetAgentKey(),
		DisplayName:   d.GetDisplayName(),
		ForbiddenTags: d.GetForbiddenTags(),
		PreferredTags: d.GetPreferredTags(),
	}
	if bot := d.GetBotUserId(); bot != "" {
		if id, err := strconv.ParseUint(bot, 10, 32); err == nil {
			s.BotUserID = uint(id)
		}
	}
	return s
}
