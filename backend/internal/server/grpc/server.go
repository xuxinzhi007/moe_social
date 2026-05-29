package grpcserver

import (
	"context"

	moev1pb "backend/api/moe/v1"
	"backend/internal/apilegacy/config"
	moebiz "backend/internal/biz/moe"
	moeadmin "backend/internal/service/moe"
	"backend/pkg/moe/brain"
)

// Server 实现 moe.v1.MoeAdmin gRPC（Phase 3 Sprint 2，与 legacy Super 并存）。
type Server struct {
	moev1pb.UnimplementedMoeAdminServer
	admin        *moeadmin.AdminService
	inferenceCfg config.LLMInferenceConf
}

// New 构造 Moe v1 gRPC 服务。
func New(admin *moeadmin.AdminService, opts ...Option) *Server {
	s := &Server{admin: admin}
	for _, o := range opts {
		o(s)
	}
	return s
}

func (s *Server) requireAdmin() (*moeadmin.AdminService, error) {
	if s.admin == nil {
		return nil, errMoeAdminNil
	}
	return s.admin, nil
}

func (s *Server) ListRuntimes(ctx context.Context, _ *moev1pb.ListRuntimesRequest) (*moev1pb.ListRuntimesReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	rows, err := admin.ListRuntimes(ctx)
	if err != nil {
		return nil, err
	}
	out := &moev1pb.ListRuntimesReply{Items: make([]*moev1pb.AgentRuntime, 0, len(rows))}
	for _, rt := range rows {
		out.Items = append(out.Items, runtimeToProto(rt))
	}
	return out, nil
}

func (s *Server) UpsertRuntime(ctx context.Context, in *moev1pb.UpsertRuntimeRequest) (*moev1pb.UpsertRuntimeReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	botUID, err := moebiz.ParseBotUserID(in.GetBotUserId())
	if err != nil {
		return nil, err
	}
	saved, err := admin.UpsertRuntime(ctx, moebiz.UpsertRuntimeParams{
		AgentKey:          in.GetAgentKey(),
		DisplayName:       in.GetDisplayName(),
		BotUserID:         botUID,
		CapabilityTier:    in.GetCapabilityTier(),
		ModelName:         in.GetModelName(),
		ProviderProfileID: in.GetProviderProfileId(),
		ToolsEnabled:      in.GetToolsEnabled(),
		PostQuotaDaily:    int(in.GetPostQuotaDaily()),
		Enabled:           in.GetEnabled(),
		SystemPrompt:      in.GetSystemPrompt(),
		PostRules:         in.GetPostRules(),
		ForbiddenTags:     in.GetForbiddenTags(),
		PreferredTags:     in.GetPreferredTags(),
		PostScheduleMode:  in.GetPostScheduleMode(),
		ScheduleCron:      in.GetScheduleCron(),
	})
	if err != nil {
		return nil, err
	}
	return &moev1pb.UpsertRuntimeReply{Item: runtimeToProto(saved)}, nil
}

func (s *Server) GetBrainPipeline(ctx context.Context, in *moev1pb.GetBrainPipelineRequest) (*moev1pb.GetBrainPipelineReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	snap, err := admin.GetBrainPipeline(ctx, in.GetAgentKey())
	if err != nil {
		return nil, err
	}
	return pipelineToProto(snap), nil
}

func (s *Server) RunAgentOnce(ctx context.Context, in *moev1pb.RunAgentOnceRequest) (*moev1pb.RunAgentOnceReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	out, err := admin.RunAgentOnce(ctx, in.GetAgentKey(), in.GetAsync())
	if err != nil {
		return nil, err
	}
	reply := &moev1pb.RunAgentOnceReply{
		AgentKey:       in.GetAgentKey(),
		Accepted:       out.Accepted,
		AlreadyRunning: out.AlreadyRunning,
	}
	if !out.Accepted && !out.AlreadyRunning {
		r := out.Result
		reply.Ok = r.OK
		reply.Detail = r.Detail
		reply.PostId = r.PostID
		if reply.AgentKey == "" {
			reply.AgentKey = r.AgentKey
		}
	}
	return reply, nil
}

func (s *Server) GetBrainSnapshot(ctx context.Context, in *moev1pb.GetBrainSnapshotRequest) (*moev1pb.GetBrainSnapshotReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	snap, err := admin.GetBrainSnapshot(ctx, in.GetAgentKey())
	if err != nil {
		return nil, err
	}
	return brainToProto(snap), nil
}

func (s *Server) UpdateBrainPolicy(ctx context.Context, in *moev1pb.UpdateBrainPolicyRequest) (*moev1pb.GetBrainSnapshotReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	snap, err := admin.UpdateBrainPolicy(ctx, in.GetAgentKey(), in.GetForbiddenTags(), in.GetPreferredTags())
	if err != nil {
		return nil, err
	}
	return brainToProto(snap), nil
}

func (s *Server) DeleteBrainEpisode(ctx context.Context, in *moev1pb.DeleteBrainEpisodeRequest) (*moev1pb.DeleteBrainEpisodeReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	if err := admin.DeleteBrainEpisode(ctx, uint(in.GetId())); err != nil {
		return nil, err
	}
	return &moev1pb.DeleteBrainEpisodeReply{}, nil
}

func (s *Server) RefineBrainEpisode(ctx context.Context, in *moev1pb.RefineBrainEpisodeRequest) (*moev1pb.RefineBrainEpisodeReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	res, err := admin.RefineBrainEpisode(ctx, uint(in.GetId()), brain.RefineOptions{MaxAttempts: int(in.GetMaxAttempts())})
	if err != nil && !res.OK {
		return nil, err
	}
	return refineToProto(res), nil
}

func (s *Server) CurateBrain(ctx context.Context, in *moev1pb.CurateBrainRequest) (*moev1pb.CurateBrainReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	results, err := admin.CurateBrain(ctx, in.GetAgentKey(), brain.CurateOptions{
		MaxEpisodes:           int(in.GetMaxEpisodes()),
		MaxAttemptsPerEpisode: int(in.GetMaxAttempts()),
		MinQuality:            int(in.GetMinQuality()),
		Force:                 in.GetForce(),
	})
	if err != nil {
		return nil, err
	}
	out := &moev1pb.CurateBrainReply{
		AgentKey: in.GetAgentKey(),
		Total:    int32(len(results)),
	}
	for _, r := range results {
		if r.Approved {
			out.Approved++
		}
		out.Results = append(out.Results, refineToProto(r))
	}
	return out, nil
}

func (s *Server) QueryToolStats(ctx context.Context, in *moev1pb.QueryToolStatsRequest) (*moev1pb.QueryToolStatsReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	stats, err := admin.QueryToolStats(ctx, moebiz.ToolStatsFilter{
		From:     moeadmin.ParseTimeFilter(in.GetFrom(), false),
		To:       moeadmin.ParseTimeFilter(in.GetTo(), true),
		AgentKey: in.GetAgentKey(),
		Tool:     in.GetTool(),
	})
	if err != nil {
		return nil, err
	}
	return toolStatsToProto(stats), nil
}

func (s *Server) ListToolCalls(ctx context.Context, in *moev1pb.ListToolCallsRequest) (*moev1pb.ListToolCallsReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	rows, total, err := admin.ListToolCalls(ctx, moebiz.ToolCallsFilter{
		From:        moeadmin.ParseTimeFilter(in.GetFrom(), false),
		To:          moeadmin.ParseTimeFilter(in.GetTo(), true),
		AgentKey:    in.GetAgentKey(),
		Tool:        in.GetTool(),
		Source:      in.GetSource(),
		ActorUserID: moebiz.ParseActorUserID(in.GetActorUserId()),
		OkOnly:      in.GetOkOnly(),
		FailedOnly:  in.GetFailedOnly(),
		Page:        int(in.GetPage()),
		PageSize:    int(in.GetPageSize()),
	})
	if err != nil {
		return nil, err
	}
	return toolCallsToProto(rows, total), nil
}
