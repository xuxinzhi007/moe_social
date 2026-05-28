package logic

import (
	"strconv"

	"backend/model"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/runtime"
	"backend/rpc/pb/moe"
)

func moeRuntimeItemProto(rt model.MoeAgentRuntime) *moe.MoeAgentRuntimeItem {
	item := runtime.ItemFromModel(rt)
	return &moe.MoeAgentRuntimeItem{
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

func moeBrainSnapshotProto(s *brain.Snapshot) *moe.AdminGetMoeBrainResp {
	if s == nil {
		return &moe.AdminGetMoeBrainResp{}
	}
	out := &moe.AdminGetMoeBrainResp{
		AgentKey:      s.AgentKey,
		DisplayName:   s.DisplayName,
		BotUserId:     strconv.FormatUint(uint64(s.BotUserID), 10),
		ForbiddenTags: s.ForbiddenTags,
		PreferredTags: s.PreferredTags,
	}
	for _, t := range s.TagStats {
		out.TagStats = append(out.TagStats, &moe.MoeBrainTagStat{Tag: t.Tag, Count: int32(t.Count)})
	}
	for _, e := range s.Episodes {
		out.Episodes = append(out.Episodes, &moe.MoeBrainEpisodeItem{
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
		out.Memories = append(out.Memories, &moe.MoeBrainMemoryItem{
			Key:        m.Key,
			Value:      m.Value,
			MemoryType: m.MemoryType,
			UpdatedAt:  m.UpdatedAt,
		})
	}
	gm := s.GenerationMeta
	out.GenerationMeta = &moe.MoeBrainGenerationMeta{
		PostUsesToolMemory: gm.PostUsesToolMemory,
		MemoriesSynced:     int32(gm.MemoriesSynced),
		EpisodesInPrompt:   int32(gm.EpisodesInPrompt),
		PromptMemoryLines:  int32(gm.PromptMemoryLines),
		PromptPreview:      gm.PromptPreview,
		PromptEstTokens:    int32(gm.PromptEstTokens),
		ContextLimit:       int32(gm.ContextLimit),
		ContextUsedPct:     gm.ContextUsedPct,
		Note:               gm.Note,
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

func moeRefineResultProto(r brain.RefineResult) *moe.AdminRefineMoeBrainEpisodeResp {
	return &moe.AdminRefineMoeBrainEpisodeResp{
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
