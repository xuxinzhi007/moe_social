package moeadmingw

import (
	"context"
	"errors"
	"fmt"
	"strings"

	moebiz "backend/internal/biz/moe"
	moepb "backend/api/moe/v1"
	"backend/api/internal/moebridge"
	moeadmin "backend/internal/service/moe"
	"backend/model"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/runtime"
	"backend/rpc/pb/super"
)

var errNoBackend = errors.New("Moe Admin 后端未配置")

// Gateway 统一 Admin Moe 路由：kratos HTTP（灰度）→ 进程内 → moe gRPC → legacy super。
type Gateway struct {
	kratos  *KratosHTTPClient
	local   *moeadmin.AdminService
	moeGRPC moepb.MoeAdminClient
	super   super.SuperClient
}

// New 构造网关；kratos 非 nil 且配置启用时，ListRuntimes/GetBrainPipeline 走纯 Kratos HTTP。
func New(local *moeadmin.AdminService, moeGRPC moepb.MoeAdminClient, legacy super.SuperClient, kratos *KratosHTTPClient) *Gateway {
	return &Gateway{local: local, moeGRPC: moeGRPC, super: legacy, kratos: kratos}
}

// Available 是否至少有一个后端。
func (g *Gateway) Available() bool {
	return g != nil && (g.kratosHTTPReady() || g.local != nil || g.moeGRPC != nil || g.super != nil)
}

func (g *Gateway) kratosHTTPReady() bool {
	return g != nil && g.kratos != nil && g.kratos.enabled()
}

// Route 当前优先路由（日志/观测）。
func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.kratosHTTPReady() {
		return "kratos_http"
	}
	if g.local != nil {
		return "in_process"
	}
	if g.moeGRPC != nil {
		return "moe_grpc"
	}
	if g.super != nil {
		return "super"
	}
	return "none"
}

func (g *Gateway) ListRuntimes(ctx context.Context) ([]model.MoeAgentRuntime, error) {
	if g == nil {
		return nil, errNoBackend
	}
	if g.kratosHTTPReady() {
		return g.kratos.ListRuntimes(ctx)
	}
	if g.local != nil {
		return g.local.ListRuntimes(ctx)
	}
	if g.moeGRPC != nil {
		rep, err := g.moeGRPC.ListRuntimes(ctx, &moepb.ListRuntimesRequest{})
		if err != nil {
			return nil, err
		}
		out := make([]model.MoeAgentRuntime, 0, len(rep.GetItems()))
		for _, item := range rep.GetItems() {
			out = append(out, runtimeModelFromProto(item))
		}
		return out, nil
	}
	if g.super != nil {
		rep, err := g.super.AdminListMoeRuntimes(ctx, &super.AdminListMoeRuntimesReq{})
		if err != nil {
			return nil, err
		}
		out := make([]model.MoeAgentRuntime, 0, len(rep.GetItems()))
		for _, item := range rep.GetItems() {
			t := moebridge.RuntimeItemFromRPC(item)
			botUID, _ := moebiz.ParseBotUserID(t.BotUserId)
			out = append(out, model.MoeAgentRuntime{
				AgentKey: t.AgentKey, DisplayName: t.DisplayName, BotUserID: botUID,
				ModelName: t.ModelName, ToolsEnabled: t.ToolsEnabled,
				PostQuotaDaily: t.PostQuotaDaily, Enabled: t.Enabled,
			})
		}
		return out, nil
	}
	return nil, errNoBackend
}

func (g *Gateway) UpsertRuntime(ctx context.Context, p moebiz.UpsertRuntimeParams) (model.MoeAgentRuntime, error) {
	if g == nil {
		return model.MoeAgentRuntime{}, errNoBackend
	}
	if g.local != nil {
		return g.local.UpsertRuntime(ctx, p)
	}
	if g.moeGRPC != nil {
		rep, err := g.moeGRPC.UpsertRuntime(ctx, &moepb.UpsertRuntimeRequest{
			AgentKey: p.AgentKey, DisplayName: p.DisplayName,
			BotUserId: fmt.Sprintf("%d", p.BotUserID), CapabilityTier: p.CapabilityTier,
			ModelName: p.ModelName, ProviderProfileId: p.ProviderProfileID,
			ToolsEnabled: p.ToolsEnabled, PostQuotaDaily: int32(p.PostQuotaDaily),
			Enabled: p.Enabled, SystemPrompt: p.SystemPrompt, PostRules: p.PostRules,
			ForbiddenTags: p.ForbiddenTags, PreferredTags: p.PreferredTags,
			PostScheduleMode: p.PostScheduleMode, ScheduleCron: p.ScheduleCron,
		})
		if err != nil {
			return model.MoeAgentRuntime{}, err
		}
		return runtimeModelFromProto(rep.GetItem()), nil
	}
	if g.super != nil {
		rep, err := g.super.AdminUpsertMoeRuntime(ctx, &super.AdminUpsertMoeRuntimeReq{
			AgentKey: p.AgentKey, DisplayName: p.DisplayName,
			BotUserId: fmt.Sprintf("%d", p.BotUserID), CapabilityTier: p.CapabilityTier,
			ModelName: p.ModelName, ProviderProfileId: p.ProviderProfileID,
			ToolsEnabled: p.ToolsEnabled, PostQuotaDaily: int32(p.PostQuotaDaily),
			Enabled: p.Enabled, SystemPrompt: p.SystemPrompt, PostRules: p.PostRules,
			ForbiddenTags: p.ForbiddenTags, PreferredTags: p.PreferredTags,
			PostScheduleMode: p.PostScheduleMode, ScheduleCron: p.ScheduleCron,
		})
		if err != nil {
			return model.MoeAgentRuntime{}, err
		}
		t := moebridge.RuntimeItemFromRPC(rep.GetItem())
		botUID, _ := moebiz.ParseBotUserID(t.BotUserId)
		return model.MoeAgentRuntime{AgentKey: t.AgentKey, DisplayName: t.DisplayName, BotUserID: botUID, ModelName: t.ModelName}, nil
	}
	return model.MoeAgentRuntime{}, errNoBackend
}

func (g *Gateway) GetBrainPipeline(ctx context.Context, agentKey string) (moebiz.PipelineSnapshot, error) {
	if g == nil {
		return moebiz.PipelineSnapshot{}, errNoBackend
	}
	if g.kratosHTTPReady() {
		return g.kratos.GetBrainPipeline(ctx, agentKey)
	}
	if g.local != nil {
		return g.local.GetBrainPipeline(ctx, agentKey)
	}
	if g.moeGRPC != nil {
		rep, err := g.moeGRPC.GetBrainPipeline(ctx, &moepb.GetBrainPipelineRequest{AgentKey: agentKey})
		if err != nil {
			return moebiz.PipelineSnapshot{}, err
		}
		return pipelineFromProto(rep), nil
	}
	if g.super != nil {
		rep, err := g.super.AdminGetMoeBrainPipeline(ctx, &super.AdminGetMoeBrainPipelineReq{AgentKey: agentKey})
		if err != nil {
			return moebiz.PipelineSnapshot{}, err
		}
		return pipelineFromSuper(rep), nil
	}
	return moebiz.PipelineSnapshot{}, errNoBackend
}

func (g *Gateway) RunAgentOnce(ctx context.Context, agentKey string) (runtime.RunOnceResult, error) {
	if g == nil {
		return runtime.RunOnceResult{}, errNoBackend
	}
	if g.local != nil {
		return g.local.RunAgentOnce(ctx, agentKey)
	}
	if g.moeGRPC != nil {
		rep, err := g.moeGRPC.RunAgentOnce(ctx, &moepb.RunAgentOnceRequest{AgentKey: agentKey})
		if err != nil {
			return runtime.RunOnceResult{}, err
		}
		r := moebridge.RunResultFromProto(rep)
		return runtime.RunOnceResult{AgentKey: r.AgentKey, OK: r.OK, Detail: r.Detail, PostID: r.PostID}, nil
	}
	if g.super != nil {
		rep, err := g.super.AdminRunMoeAgentOnce(ctx, &super.AdminRunMoeAgentOnceReq{AgentKey: agentKey})
		if err != nil {
			return runtime.RunOnceResult{}, err
		}
		return runtime.RunOnceResult{
			AgentKey: rep.GetAgentKey(), OK: rep.GetOk(),
			Detail: rep.GetDetail(), PostID: rep.GetPostId(),
		}, nil
	}
	return runtime.RunOnceResult{}, errNoBackend
}

func (g *Gateway) GetBrainSnapshot(ctx context.Context, agentKey string) (*brain.Snapshot, error) {
	if g == nil {
		return nil, errNoBackend
	}
	if g.local != nil {
		return g.local.GetBrainSnapshot(ctx, agentKey)
	}
	if g.moeGRPC != nil {
		rep, err := g.moeGRPC.GetBrainSnapshot(ctx, &moepb.GetBrainSnapshotRequest{AgentKey: agentKey})
		if err != nil {
			return nil, err
		}
		return moebridge.BrainSnapshotFromProto(rep), nil
	}
	if g.super != nil {
		rep, err := g.super.AdminGetMoeBrain(ctx, &super.AdminGetMoeBrainReq{AgentKey: agentKey})
		if err != nil {
			return nil, err
		}
		return brainDataToSnapshot(moebridge.BrainDataFromRPC(rep)), nil
	}
	return nil, errNoBackend
}

func (g *Gateway) UpdateBrainPolicy(ctx context.Context, agentKey string, forbidden, preferred []string) (*brain.Snapshot, error) {
	if g == nil {
		return nil, errNoBackend
	}
	if g.local != nil {
		return g.local.UpdateBrainPolicy(ctx, agentKey, forbidden, preferred)
	}
	if g.moeGRPC != nil {
		rep, err := g.moeGRPC.UpdateBrainPolicy(ctx, &moepb.UpdateBrainPolicyRequest{
			AgentKey: agentKey, ForbiddenTags: forbidden, PreferredTags: preferred,
		})
		if err != nil {
			return nil, err
		}
		return moebridge.BrainSnapshotFromProto(rep), nil
	}
	if g.super != nil {
		rep, err := g.super.AdminUpdateMoeBrainPolicy(ctx, &super.AdminUpdateMoeBrainPolicyReq{
			AgentKey: agentKey, ForbiddenTags: forbidden, PreferredTags: preferred,
		})
		if err != nil {
			return nil, err
		}
		return brainDataToSnapshot(moebridge.BrainDataFromRPC(rep)), nil
	}
	return nil, errNoBackend
}

func (g *Gateway) DeleteBrainEpisode(ctx context.Context, id uint) error {
	if g == nil {
		return errNoBackend
	}
	if g.local != nil {
		return g.local.DeleteBrainEpisode(ctx, id)
	}
	if g.moeGRPC != nil {
		_, err := g.moeGRPC.DeleteBrainEpisode(ctx, &moepb.DeleteBrainEpisodeRequest{Id: uint64(id)})
		return err
	}
	if g.super != nil {
		_, err := g.super.AdminDeleteMoeBrainEpisode(ctx, &super.AdminDeleteMoeBrainEpisodeReq{Id: uint64(id)})
		return err
	}
	return errNoBackend
}

func (g *Gateway) RefineBrainEpisode(ctx context.Context, id uint, opt brain.RefineOptions) (brain.RefineResult, error) {
	if g == nil {
		return brain.RefineResult{}, errNoBackend
	}
	if g.local != nil {
		return g.local.RefineBrainEpisode(ctx, id, opt)
	}
	if g.moeGRPC != nil {
		rep, err := g.moeGRPC.RefineBrainEpisode(ctx, &moepb.RefineBrainEpisodeRequest{
			Id: uint64(id), MaxAttempts: int32(opt.MaxAttempts),
		})
		if err != nil {
			return brain.RefineResult{}, err
		}
		d := moebridge.RefineResultFromProto(rep)
		return brain.RefineResult{
			EpisodeID: d.EpisodeId, OK: d.Ok, Approved: d.Approved,
			QualityScore: d.QualityScore, BeforeContent: d.BeforeContent,
			AfterContent: d.AfterContent, Attempts: d.Attempts, Detail: d.Detail,
		}, nil
	}
	if g.super != nil {
		rep, err := g.super.AdminRefineMoeBrainEpisode(ctx, &super.AdminRefineMoeBrainEpisodeReq{
			Id: uint64(id), MaxAttempts: int32(opt.MaxAttempts),
		})
		if err != nil {
			return brain.RefineResult{}, err
		}
		d := moebridge.RefineResultFromRPC(rep)
		return brain.RefineResult{
			EpisodeID: d.EpisodeId, OK: d.Ok, Approved: d.Approved,
			QualityScore: d.QualityScore, BeforeContent: d.BeforeContent,
			AfterContent: d.AfterContent, Attempts: d.Attempts, Detail: d.Detail,
		}, nil
	}
	return brain.RefineResult{}, errNoBackend
}

func (g *Gateway) CurateBrain(ctx context.Context, agentKey string, opt brain.CurateOptions) ([]brain.RefineResult, error) {
	if g == nil {
		return nil, errNoBackend
	}
	if g.local != nil {
		return g.local.CurateBrain(ctx, agentKey, opt)
	}
	if g.moeGRPC != nil {
		rep, err := g.moeGRPC.CurateBrain(ctx, &moepb.CurateBrainRequest{
			AgentKey: agentKey, MaxEpisodes: int32(opt.MaxEpisodes),
			MaxAttempts: int32(opt.MaxAttemptsPerEpisode), MinQuality: int32(opt.MinQuality), Force: opt.Force,
		})
		if err != nil {
			return nil, err
		}
		return curateResultsFromProto(rep), nil
	}
	if g.super != nil {
		rep, err := g.super.AdminCurateMoeBrain(ctx, &super.AdminCurateMoeBrainReq{
			AgentKey: agentKey, MaxEpisodes: int32(opt.MaxEpisodes),
			MaxAttempts: int32(opt.MaxAttemptsPerEpisode), MinQuality: int32(opt.MinQuality), Force: opt.Force,
		})
		if err != nil {
			return nil, err
		}
		out := make([]brain.RefineResult, 0, len(rep.GetResults()))
		for _, r := range rep.GetResults() {
			d := moebridge.RefineResultFromRPC(r)
			out = append(out, brain.RefineResult{
				EpisodeID: d.EpisodeId, OK: d.Ok, Approved: d.Approved, QualityScore: d.QualityScore, Detail: d.Detail,
			})
		}
		return out, nil
	}
	return nil, errNoBackend
}

func curateResultsFromProto(rep *moepb.CurateBrainReply) []brain.RefineResult {
	if rep == nil {
		return nil
	}
	out := make([]brain.RefineResult, 0, len(rep.GetResults()))
	for _, r := range rep.GetResults() {
		d := moebridge.RefineResultFromProto(r)
		out = append(out, brain.RefineResult{
			EpisodeID: d.EpisodeId, OK: d.Ok, Approved: d.Approved, QualityScore: d.QualityScore, Detail: d.Detail,
		})
	}
	return out
}

func (g *Gateway) QueryToolStats(ctx context.Context, f moebiz.ToolStatsFilter) (moebiz.ToolStatsResult, error) {
	if g == nil {
		return moebiz.ToolStatsResult{}, errNoBackend
	}
	if g.local != nil {
		return g.local.QueryToolStats(ctx, f)
	}
	if g.moeGRPC != nil {
		rep, err := g.moeGRPC.QueryToolStats(ctx, &moepb.QueryToolStatsRequest{
			From: timeFilterStr(f.From), To: timeFilterStr(f.To),
			AgentKey: f.AgentKey, Tool: f.Tool,
		})
		if err != nil {
			return moebiz.ToolStatsResult{}, err
		}
		return toolStatsToBiz(moebridge.ToolStatsFromProto(rep)), nil
	}
	if g.super != nil {
		rep, err := g.super.AdminGetMoeToolStats(ctx, &super.AdminGetMoeToolStatsReq{
			From: timeFilterStr(f.From), To: timeFilterStr(f.To),
			AgentKey: f.AgentKey, Tool: f.Tool,
		})
		if err != nil {
			return moebiz.ToolStatsResult{}, err
		}
		return toolStatsToBiz(moebridge.ToolStatsFromRPC(rep)), nil
	}
	return moebiz.ToolStatsResult{}, errNoBackend
}

func (g *Gateway) ListToolCalls(ctx context.Context, f moebiz.ToolCallsFilter) ([]moebiz.ToolCallRow, int64, error) {
	if g == nil {
		return nil, 0, errNoBackend
	}
	if g.local != nil {
		return g.local.ListToolCalls(ctx, f)
	}
	actorStr := ""
	if f.ActorUserID != 0 {
		actorStr = fmt.Sprintf("%d", f.ActorUserID)
	}
	if g.moeGRPC != nil {
		rep, err := g.moeGRPC.ListToolCalls(ctx, &moepb.ListToolCallsRequest{
			From: timeFilterStr(f.From), To: timeFilterStr(f.To),
			AgentKey: f.AgentKey, Tool: f.Tool, Source: f.Source,
			ActorUserId: actorStr, OkOnly: f.OkOnly, FailedOnly: f.FailedOnly,
			Page: int32(f.Page), PageSize: int32(f.PageSize),
		})
		if err != nil {
			return nil, 0, err
		}
		d := moebridge.ToolCallsFromProto(rep)
		return toolCallsToBiz(d), d.Total, nil
	}
	if g.super != nil {
		rep, err := g.super.AdminListMoeToolCalls(ctx, &super.AdminListMoeToolCallsReq{
			From: timeFilterStr(f.From), To: timeFilterStr(f.To),
			AgentKey: f.AgentKey, Tool: f.Tool, Source: f.Source,
			ActorUserId: actorStr, OkOnly: f.OkOnly, FailedOnly: f.FailedOnly,
			Page: int32(f.Page), PageSize: int32(f.PageSize),
		})
		if err != nil {
			return nil, 0, err
		}
		d := moebridge.ToolCallsFromRPC(rep)
		return toolCallsToBiz(d), d.Total, nil
	}
	return nil, 0, errNoBackend
}

// FindRuntimeByAgentKey 按 agent_key 查找运行时（推理状态页等）。
func (g *Gateway) FindRuntimeByAgentKey(ctx context.Context, agentKey string) *model.MoeAgentRuntime {
	agentKey = strings.TrimSpace(agentKey)
	if agentKey == "" || g == nil || !g.Available() {
		return nil
	}
	rows, err := g.ListRuntimes(ctx)
	if err != nil {
		return nil
	}
	for i := range rows {
		if rows[i].AgentKey == agentKey {
			return &rows[i]
		}
	}
	return nil
}
