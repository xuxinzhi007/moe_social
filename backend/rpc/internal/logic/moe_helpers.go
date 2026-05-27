package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/pkg/llminference"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/port"
	"backend/pkg/moe/runtime"
	"backend/pkg/moe/tools"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/spf13/viper"
)

type localSuperPort struct {
	ctx context.Context
	svc *svc.ServiceContext
}

func newLocalSuperPort(ctx context.Context, svc *svc.ServiceContext) port.SuperPort {
	return localSuperPort{ctx: ctx, svc: svc}
}

func (l localSuperPort) GetUserMemories(ctx context.Context, in *super.GetUserMemoriesReq) (*super.GetUserMemoriesResp, error) {
	return NewGetUserMemoriesLogic(ctx, l.svc).GetUserMemories(in)
}

func (l localSuperPort) UpsertUserMemory(ctx context.Context, in *super.UpsertUserMemoryReq) (*super.UpsertUserMemoryResp, error) {
	return NewUpsertUserMemoryLogic(ctx, l.svc).UpsertUserMemory(in)
}

func (l localSuperPort) DeleteUserMemory(ctx context.Context, in *super.DeleteUserMemoryReq) (*super.DeleteUserMemoryResp, error) {
	return NewDeleteUserMemoryLogic(ctx, l.svc).DeleteUserMemory(in)
}

func (l localSuperPort) CreatePost(ctx context.Context, in *super.CreatePostReq) (*super.CreatePostResp, error) {
	return NewCreatePostLogic(ctx, l.svc).CreatePost(in)
}

func (l localSuperPort) UpdatePost(ctx context.Context, in *super.UpdatePostReq) (*super.UpdatePostResp, error) {
	return NewUpdatePostLogic(ctx, l.svc).UpdatePost(in)
}

func (l localSuperPort) GetPost(ctx context.Context, in *super.GetPostReq) (*super.GetPostResp, error) {
	return NewGetPostLogic(ctx, l.svc).GetPost(in)
}

func moeRuntimeDeps(ctx context.Context, svc *svc.ServiceContext) runtime.Deps {
	return runtime.Deps{
		DB:        svc.DB,
		RPC:       newLocalSuperPort(ctx, svc),
		Inference: moeInferenceFromViper(),
	}
}

func moeToolsDeps(ctx context.Context, svc *svc.ServiceContext) tools.Deps {
	return tools.Deps{
		DB:        svc.DB,
		RPC:       newLocalSuperPort(ctx, svc),
		Inference: moeInferenceFromViper(),
	}
}

func moeBrainDeps(ctx context.Context, svc *svc.ServiceContext) brain.Deps {
	return brain.Deps{
		DB:  svc.DB,
		RPC: newLocalSuperPort(ctx, svc),
	}
}

func moeBrainRefineDeps(ctx context.Context, svc *svc.ServiceContext) brain.RefineDeps {
	return brain.RefineDeps{
		DB:        svc.DB,
		RPC:       newLocalSuperPort(ctx, svc),
		Inference: moeInferenceFromViper(),
	}
}

func moeInferenceFromViper() llminference.Config {
	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")
	_ = v.ReadInConfig()
	base := v.GetString("llm_inference.base_url")
	if base == "" {
		base = v.GetString("ollama.base_url")
	}
	style := v.GetString("llm_inference.api_style")
	if style == "" {
		style = v.GetString("ollama.api_style")
	}
	ts := v.GetInt("llm_inference.timeout_seconds")
	if ts <= 0 {
		ts = v.GetInt("ollama.timeout_seconds")
	}
	model := v.GetString("llm_inference.memory_model")
	if model == "" {
		model = v.GetString("ollama.memory_model")
	}
	return llminference.ConfigFrom(base, style, ts, model)
}

func moeRuntimeItemProto(rt model.MoeAgentRuntime) *super.MoeAgentRuntimeItem {
	item := runtime.ItemFromModel(rt)
	return &super.MoeAgentRuntimeItem{
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

func moeBrainSnapshotProto(s *brain.Snapshot) *super.AdminGetMoeBrainResp {
	if s == nil {
		return &super.AdminGetMoeBrainResp{}
	}
	out := &super.AdminGetMoeBrainResp{
		AgentKey:      s.AgentKey,
		DisplayName:   s.DisplayName,
		BotUserId:     strconv.FormatUint(uint64(s.BotUserID), 10),
		ForbiddenTags: s.ForbiddenTags,
		PreferredTags: s.PreferredTags,
	}
	for _, t := range s.TagStats {
		out.TagStats = append(out.TagStats, &super.MoeBrainTagStat{Tag: t.Tag, Count: int32(t.Count)})
	}
	for _, e := range s.Episodes {
		out.Episodes = append(out.Episodes, &super.MoeBrainEpisodeItem{
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
		out.Memories = append(out.Memories, &super.MoeBrainMemoryItem{
			Key:        m.Key,
			Value:      m.Value,
			MemoryType: m.MemoryType,
			UpdatedAt:  m.UpdatedAt,
		})
	}
	gm := s.GenerationMeta
	out.GenerationMeta = &super.MoeBrainGenerationMeta{
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
	return out
}

func moeRefineResultProto(r brain.RefineResult) *super.AdminRefineMoeBrainEpisodeResp {
	return &super.AdminRefineMoeBrainEpisodeResp{
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

// StartBotScheduler 在 RPC 进程启动 Bot 定时发帖。
func StartBotScheduler(parent context.Context, svc *svc.ServiceContext) {
	sched := runtime.LoadSchedulerOptsFromViper()
	runtime.StartScheduler(parent, moeRuntimeDeps(parent, svc), sched.SchedulerOpts, sched.Smart)
}
