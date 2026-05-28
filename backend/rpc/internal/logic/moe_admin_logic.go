package logic

import (
	"context"
	"strconv"
	"strings"
	"time"

	moebiz "backend/internal/biz/moe"
	postbiz "backend/internal/biz/post"
	moeadmin "backend/internal/service/moe"
	"backend/pkg/moe/brain"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListMoeRuntimesLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListMoeRuntimesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListMoeRuntimesLogic {
	return &AdminListMoeRuntimesLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListMoeRuntimesLogic) AdminListMoeRuntimes(_ *moe.AdminListMoeRuntimesReq) (*moe.AdminListMoeRuntimesResp, error) {
	rows, err := l.svcCtx.MoeAdmin.ListRuntimes(l.ctx)
	if err != nil {
		return nil, errorx.Internal(err.Error())
	}
	out := &moe.AdminListMoeRuntimesResp{Items: make([]*moe.MoeAgentRuntimeItem, 0, len(rows))}
	for _, rt := range rows {
		out.Items = append(out.Items, moeRuntimeItemProto(rt))
	}
	return out, nil
}

type AdminUpsertMoeRuntimeLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpsertMoeRuntimeLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpsertMoeRuntimeLogic {
	return &AdminUpsertMoeRuntimeLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpsertMoeRuntimeLogic) AdminUpsertMoeRuntime(in *moe.AdminUpsertMoeRuntimeReq) (*moe.AdminUpsertMoeRuntimeResp, error) {
	botUID, err := moebiz.ParseBotUserID(in.BotUserId)
	if err != nil {
		return nil, errorx.InvalidArgument(err.Error())
	}
	saved, err := l.svcCtx.MoeAdmin.UpsertRuntime(l.ctx, moebiz.UpsertRuntimeParams{
		AgentKey:          in.AgentKey,
		DisplayName:       in.DisplayName,
		BotUserID:         botUID,
		CapabilityTier:    in.CapabilityTier,
		ModelName:         in.ModelName,
		ProviderProfileID: in.ProviderProfileId,
		ToolsEnabled:      in.ToolsEnabled,
		PostQuotaDaily:    int(in.PostQuotaDaily),
		Enabled:           in.Enabled,
		SystemPrompt:      in.SystemPrompt,
		PostRules:         in.PostRules,
		ForbiddenTags:     in.ForbiddenTags,
		PreferredTags:     in.PreferredTags,
		PostScheduleMode:  in.PostScheduleMode,
		ScheduleCron:      in.ScheduleCron,
	})
	if err != nil {
		return nil, errorx.InvalidArgument(err.Error())
	}
	return &moe.AdminUpsertMoeRuntimeResp{Item: moeRuntimeItemProto(saved)}, nil
}

type AdminRunMoeAgentOnceLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminRunMoeAgentOnceLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminRunMoeAgentOnceLogic {
	return &AdminRunMoeAgentOnceLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminRunMoeAgentOnceLogic) AdminRunMoeAgentOnce(in *moe.AdminRunMoeAgentOnceReq) (*moe.AdminRunMoeAgentOnceResp, error) {
	out, err := l.svcCtx.MoeAdmin.RunAgentOnce(l.ctx, strings.TrimSpace(in.AgentKey), in.GetAsync())
	if err != nil {
		return nil, errorx.Internal(err.Error())
	}
	rep := &moe.AdminRunMoeAgentOnceResp{
		AgentKey:       strings.TrimSpace(in.AgentKey),
		Accepted:       out.Accepted,
		AlreadyRunning: out.AlreadyRunning,
	}
	if out.Accepted || out.AlreadyRunning {
		return rep, nil
	}
	r := out.Result
	rep.Ok = r.OK
	rep.Detail = r.Detail
	rep.PostId = r.PostID
	if rep.AgentKey == "" {
		rep.AgentKey = r.AgentKey
	}
	return rep, nil
}

type AdminGetMoeBrainLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetMoeBrainLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMoeBrainLogic {
	return &AdminGetMoeBrainLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminGetMoeBrainLogic) AdminGetMoeBrain(in *moe.AdminGetMoeBrainReq) (*moe.AdminGetMoeBrainResp, error) {
	snap, err := l.svcCtx.MoeAdmin.GetBrainSnapshot(l.ctx, strings.TrimSpace(in.AgentKey))
	if err != nil {
		return nil, errorx.NotFound(err.Error())
	}
	return moeBrainSnapshotProto(snap), nil
}

type AdminUpdateMoeBrainPolicyLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateMoeBrainPolicyLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateMoeBrainPolicyLogic {
	return &AdminUpdateMoeBrainPolicyLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpdateMoeBrainPolicyLogic) AdminUpdateMoeBrainPolicy(in *moe.AdminUpdateMoeBrainPolicyReq) (*moe.AdminGetMoeBrainResp, error) {
	snap, err := l.svcCtx.MoeAdmin.UpdateBrainPolicy(l.ctx, strings.TrimSpace(in.AgentKey), in.ForbiddenTags, in.PreferredTags)
	if err != nil {
		return nil, errorx.Internal(err.Error())
	}
	return moeBrainSnapshotProto(snap), nil
}

type AdminDeleteMoeBrainEpisodeLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteMoeBrainEpisodeLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteMoeBrainEpisodeLogic {
	return &AdminDeleteMoeBrainEpisodeLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteMoeBrainEpisodeLogic) AdminDeleteMoeBrainEpisode(in *moe.AdminDeleteMoeBrainEpisodeReq) (*moe.AdminDeleteMoeBrainEpisodeResp, error) {
	if err := l.svcCtx.MoeAdmin.DeleteBrainEpisode(l.ctx, uint(in.Id)); err != nil {
		return nil, errorx.NotFound(err.Error())
	}
	return &moe.AdminDeleteMoeBrainEpisodeResp{}, nil
}

type AdminRefineMoeBrainEpisodeLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminRefineMoeBrainEpisodeLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminRefineMoeBrainEpisodeLogic {
	return &AdminRefineMoeBrainEpisodeLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminRefineMoeBrainEpisodeLogic) AdminRefineMoeBrainEpisode(in *moe.AdminRefineMoeBrainEpisodeReq) (*moe.AdminRefineMoeBrainEpisodeResp, error) {
	res, err := l.svcCtx.MoeAdmin.RefineBrainEpisode(l.ctx, uint(in.Id), brain.RefineOptions{
		MaxAttempts: int(in.MaxAttempts),
	})
	if err != nil && !res.OK {
		return nil, errorx.Internal(err.Error())
	}
	return moeRefineResultProto(res), nil
}

type AdminCurateMoeBrainLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminCurateMoeBrainLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCurateMoeBrainLogic {
	return &AdminCurateMoeBrainLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminCurateMoeBrainLogic) AdminCurateMoeBrain(in *moe.AdminCurateMoeBrainReq) (*moe.AdminCurateMoeBrainResp, error) {
	results, err := l.svcCtx.MoeAdmin.CurateBrain(l.ctx, strings.TrimSpace(in.AgentKey), brain.CurateOptions{
		MaxEpisodes:           int(in.MaxEpisodes),
		MaxAttemptsPerEpisode: int(in.MaxAttempts),
		MinQuality:            int(in.MinQuality),
		Force:                 in.Force,
	})
	if err != nil {
		return nil, errorx.Internal(err.Error())
	}
	out := &moe.AdminCurateMoeBrainResp{
		AgentKey: in.AgentKey,
		Total:    int32(len(results)),
	}
	for _, r := range results {
		if r.Approved {
			out.Approved++
		}
		out.Results = append(out.Results, moeRefineResultProto(r))
	}
	return out, nil
}

type AdminGetMoeToolStatsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetMoeToolStatsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMoeToolStatsLogic {
	return &AdminGetMoeToolStatsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminGetMoeToolStatsLogic) AdminGetMoeToolStats(in *moe.AdminGetMoeToolStatsReq) (*moe.AdminGetMoeToolStatsResp, error) {
	stats, err := l.svcCtx.MoeAdmin.QueryToolStats(l.ctx, moebiz.ToolStatsFilter{
		From:     moeadmin.ParseTimeFilter(in.From, false),
		To:       moeadmin.ParseTimeFilter(in.To, true),
		AgentKey: in.AgentKey,
		Tool:     in.Tool,
	})
	if err != nil {
		return nil, errorx.Internal(err.Error())
	}
	out := &moe.AdminGetMoeToolStatsResp{
		TotalCalls:   stats.TotalCalls,
		SuccessCalls: stats.SuccessCalls,
		FailedCalls:  stats.FailedCalls,
	}
	for _, row := range stats.ByTool {
		out.ByTool = append(out.ByTool, &moe.AdminMoeToolStatRow{
			Tool:         row.Tool,
			TotalCalls:   row.TotalCalls,
			SuccessCalls: row.SuccessCalls,
			FailedCalls:  row.FailedCalls,
		})
	}
	for _, row := range stats.ByDay {
		out.ByDay = append(out.ByDay, &moe.AdminMoeToolDayStat{
			Date:         row.Date,
			TotalCalls:   row.TotalCalls,
			SuccessCalls: row.SuccessCalls,
		})
	}
	return out, nil
}

type AdminListMoeToolCallsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListMoeToolCallsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListMoeToolCallsLogic {
	return &AdminListMoeToolCallsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListMoeToolCallsLogic) AdminListMoeToolCalls(in *moe.AdminListMoeToolCallsReq) (*moe.AdminListMoeToolCallsResp, error) {
	rows, total, err := l.svcCtx.MoeAdmin.ListToolCalls(l.ctx, moebiz.ToolCallsFilter{
		From:        moeadmin.ParseTimeFilter(in.From, false),
		To:          moeadmin.ParseTimeFilter(in.To, true),
		AgentKey:    in.AgentKey,
		Tool:        in.Tool,
		Source:      in.Source,
		ActorUserID: moebiz.ParseActorUserID(in.ActorUserId),
		OkOnly:      in.OkOnly,
		FailedOnly:  in.FailedOnly,
		Page:        int(in.Page),
		PageSize:    int(in.PageSize),
	})
	if err != nil {
		return nil, errorx.Internal(err.Error())
	}
	out := &moe.AdminListMoeToolCallsResp{Total: total}
	for _, row := range rows {
		out.Items = append(out.Items, &moe.AdminMoeToolCallItem{
			Id:               strconv.FormatUint(uint64(row.ID), 10),
			Tool:             row.Tool,
			ActorUserId:      strconv.FormatUint(uint64(row.ActorUserID), 10),
			AgentKey:         row.AgentKey,
			Ok:               row.Ok,
			ErrorMsg:         row.ErrorMsg,
			LatencyMs:        int32(row.LatencyMs),
			Source:           row.Source,
			ArgumentsPreview: row.ArgumentsPreview,
			CreatedAt:        row.CreatedAt.Format(time.DateTime),
		})
	}
	return out, nil
}

type MoeExecuteToolLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewMoeExecuteToolLogic(ctx context.Context, svcCtx *svc.ServiceContext) *MoeExecuteToolLogic {
	return &MoeExecuteToolLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *MoeExecuteToolLogic) MoeExecuteTool(in *moe.MoeExecuteToolReq) (*moe.MoeExecuteToolResp, error) {
	res, err := l.svcCtx.MoeAdmin.ExecuteTool(l.ctx, moebiz.ExecuteToolInput{
		Tool:           in.Tool,
		ArgumentsJSON:  in.ArgumentsJson,
		ActorUserID:    uint(in.ActorUserId),
		AgentKey:       in.AgentKey,
		Source:         in.Source,
		IdempotencyKey: in.IdempotencyKey,
	})
	if err != nil {
		return nil, errorx.Internal(err.Error())
	}
	return &moe.MoeExecuteToolResp{Ok: res.OK, Result: res.Result, Error: res.Error}, nil
}

type MoeSearchPostsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewMoeSearchPostsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *MoeSearchPostsLogic {
	return &MoeSearchPostsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *MoeSearchPostsLogic) MoeSearchPosts(in *moe.MoeSearchPostsReq) (*moe.MoeSearchPostsResp, error) {
	out, err := postbiz.Search(l.ctx, l.svcCtx.PostStore(), postbiz.SearchInput{
		Query: in.GetQuery(), Limit: in.GetLimit(), ViewerUserID: in.GetViewerUserId(),
		MoodTag: in.GetMoodTag(), TopicTagID: in.GetTopicTagId(),
	})
	if err != nil {
		return nil, errorx.Internal("检索失败")
	}
	return out, nil
}
