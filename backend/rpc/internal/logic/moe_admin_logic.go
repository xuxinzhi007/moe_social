package logic

import (
	"context"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/runtime"
	"backend/pkg/moe/toolaudit"
	"backend/pkg/moe/tools"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

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

func (l *AdminListMoeRuntimesLogic) AdminListMoeRuntimes(_ *super.AdminListMoeRuntimesReq) (*super.AdminListMoeRuntimesResp, error) {
	rows, err := runtime.ListRuntimes(l.svcCtx.DB)
	if err != nil {
		return nil, errorx.Internal(err.Error())
	}
	out := &super.AdminListMoeRuntimesResp{Items: make([]*super.MoeAgentRuntimeItem, 0, len(rows))}
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

func (l *AdminUpsertMoeRuntimeLogic) AdminUpsertMoeRuntime(in *super.AdminUpsertMoeRuntimeReq) (*super.AdminUpsertMoeRuntimeResp, error) {
	botUID, err := strconv.ParseUint(strings.TrimSpace(in.BotUserId), 10, 32)
	if err != nil || botUID == 0 {
		return nil, errorx.InvalidArgument("无效的 bot_user_id")
	}
	tier := strings.TrimSpace(in.CapabilityTier)
	if tier == "" {
		tier = "s2"
	}
	quota := int(in.PostQuotaDaily)
	if quota <= 0 {
		quota = 5
	}
	rt := &model.MoeAgentRuntime{
		AgentKey:          strings.TrimSpace(in.AgentKey),
		DisplayName:       strings.TrimSpace(in.DisplayName),
		BotUserID:         uint(botUID),
		CapabilityTier:    tier,
		ModelName:         strings.TrimSpace(in.ModelName),
		ProviderProfileID: strings.TrimSpace(in.ProviderProfileId),
		ToolsEnabled:      in.ToolsEnabled,
		PostQuotaDaily:    quota,
		Enabled:           in.Enabled,
		SystemPrompt:      strings.TrimSpace(in.SystemPrompt),
		PostRules:         strings.TrimSpace(in.PostRules),
		ForbiddenTags:     strings.TrimSpace(in.ForbiddenTags),
		PreferredTags:     strings.TrimSpace(in.PreferredTags),
		PostScheduleMode:  runtime.NormalizeScheduleMode(in.PostScheduleMode),
		ScheduleCron:      strings.TrimSpace(in.ScheduleCron),
	}
	if err := runtime.UpsertRuntime(l.svcCtx.DB, rt); err != nil {
		return nil, errorx.InvalidArgument(err.Error())
	}
	_ = l.svcCtx.DB.Model(&model.User{}).Where("id = ?", botUID).Updates(map[string]any{
		"is_bot":        true,
		"bot_agent_key": rt.AgentKey,
	}).Error
	var saved model.MoeAgentRuntime
	_ = l.svcCtx.DB.Where("agent_key = ?", rt.AgentKey).First(&saved).Error
	return &super.AdminUpsertMoeRuntimeResp{Item: moeRuntimeItemProto(saved)}, nil
}

type AdminRunMoeAgentOnceLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminRunMoeAgentOnceLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminRunMoeAgentOnceLogic {
	return &AdminRunMoeAgentOnceLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminRunMoeAgentOnceLogic) AdminRunMoeAgentOnce(in *super.AdminRunMoeAgentOnceReq) (*super.AdminRunMoeAgentOnceResp, error) {
	result, err := runtime.RunOnce(l.ctx, moeRuntimeDeps(l.ctx, l.svcCtx), strings.TrimSpace(in.AgentKey))
	if err != nil {
		return nil, errorx.Internal(err.Error())
	}
	return &super.AdminRunMoeAgentOnceResp{
		AgentKey: result.AgentKey,
		Ok:       result.OK,
		Detail:   result.Detail,
		PostId:   result.PostID,
	}, nil
}

type AdminGetMoeBrainLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetMoeBrainLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMoeBrainLogic {
	return &AdminGetMoeBrainLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminGetMoeBrainLogic) AdminGetMoeBrain(in *super.AdminGetMoeBrainReq) (*super.AdminGetMoeBrainResp, error) {
	snap, err := brain.LoadSnapshot(l.ctx, l.svcCtx.DB, newLocalSuperPort(l.ctx, l.svcCtx), strings.TrimSpace(in.AgentKey))
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

func (l *AdminUpdateMoeBrainPolicyLogic) AdminUpdateMoeBrainPolicy(in *super.AdminUpdateMoeBrainPolicyReq) (*super.AdminGetMoeBrainResp, error) {
	forbidden := brain.ParseTagList(strings.Join(in.ForbiddenTags, "\n"))
	preferred := brain.ParseTagList(strings.Join(in.PreferredTags, "\n"))
	if err := brain.UpdatePolicy(l.svcCtx.DB, strings.TrimSpace(in.AgentKey), forbidden, preferred); err != nil {
		return nil, errorx.Internal(err.Error())
	}
	snap, err := brain.LoadSnapshot(l.ctx, l.svcCtx.DB, newLocalSuperPort(l.ctx, l.svcCtx), strings.TrimSpace(in.AgentKey))
	if err != nil {
		return nil, errorx.NotFound(err.Error())
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

func (l *AdminDeleteMoeBrainEpisodeLogic) AdminDeleteMoeBrainEpisode(in *super.AdminDeleteMoeBrainEpisodeReq) (*super.AdminDeleteMoeBrainEpisodeResp, error) {
	if err := brain.DeleteEpisode(l.ctx, moeBrainDeps(l.ctx, l.svcCtx), uint(in.Id)); err != nil {
		return nil, errorx.NotFound(err.Error())
	}
	return &super.AdminDeleteMoeBrainEpisodeResp{}, nil
}

type AdminRefineMoeBrainEpisodeLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminRefineMoeBrainEpisodeLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminRefineMoeBrainEpisodeLogic {
	return &AdminRefineMoeBrainEpisodeLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminRefineMoeBrainEpisodeLogic) AdminRefineMoeBrainEpisode(in *super.AdminRefineMoeBrainEpisodeReq) (*super.AdminRefineMoeBrainEpisodeResp, error) {
	res, err := brain.RefineEpisode(l.ctx, moeBrainRefineDeps(l.ctx, l.svcCtx), uint(in.Id), brain.RefineOptions{
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

func (l *AdminCurateMoeBrainLogic) AdminCurateMoeBrain(in *super.AdminCurateMoeBrainReq) (*super.AdminCurateMoeBrainResp, error) {
	results, err := brain.CurateLowQuality(l.ctx, moeBrainRefineDeps(l.ctx, l.svcCtx), strings.TrimSpace(in.AgentKey), brain.CurateOptions{
		MaxEpisodes:           int(in.MaxEpisodes),
		MaxAttemptsPerEpisode: int(in.MaxAttempts),
		MinQuality:            int(in.MinQuality),
		Force:                 in.Force,
	})
	if err != nil {
		return nil, errorx.Internal(err.Error())
	}
	out := &super.AdminCurateMoeBrainResp{
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

func (l *AdminGetMoeToolStatsLogic) AdminGetMoeToolStats(in *super.AdminGetMoeToolStatsReq) (*super.AdminGetMoeToolStatsResp, error) {
	stats, err := toolaudit.QueryStats(l.svcCtx.DB, toolaudit.StatsFilter{
		From:     toolaudit.ParseTimeFilter(in.From, false),
		To:       toolaudit.ParseTimeFilter(in.To, true),
		AgentKey: strings.TrimSpace(in.AgentKey),
		Tool:     strings.TrimSpace(in.Tool),
	})
	if err != nil {
		return nil, errorx.Internal(err.Error())
	}
	out := &super.AdminGetMoeToolStatsResp{
		TotalCalls:   stats.TotalCalls,
		SuccessCalls: stats.SuccessCalls,
		FailedCalls:  stats.FailedCalls,
	}
	for _, row := range stats.ByTool {
		out.ByTool = append(out.ByTool, &super.AdminMoeToolStatRow{
			Tool:         row.Tool,
			TotalCalls:   row.TotalCalls,
			SuccessCalls: row.SuccessCalls,
			FailedCalls:  row.FailedCalls,
		})
	}
	for _, row := range stats.ByDay {
		out.ByDay = append(out.ByDay, &super.AdminMoeToolDayStat{
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

func (l *AdminListMoeToolCallsLogic) AdminListMoeToolCalls(in *super.AdminListMoeToolCallsReq) (*super.AdminListMoeToolCallsResp, error) {
	var actorUID uint
	if raw := strings.TrimSpace(in.ActorUserId); raw != "" {
		if v, err := strconv.ParseUint(raw, 10, 32); err == nil {
			actorUID = uint(v)
		}
	}
	rows, total, err := toolaudit.ListCalls(l.svcCtx.DB, toolaudit.ListFilter{
		From:        toolaudit.ParseTimeFilter(in.From, false),
		To:          toolaudit.ParseTimeFilter(in.To, true),
		AgentKey:    strings.TrimSpace(in.AgentKey),
		Tool:        strings.TrimSpace(in.Tool),
		Source:      strings.TrimSpace(in.Source),
		ActorUserID: actorUID,
		OkOnly:      in.OkOnly,
		FailedOnly:  in.FailedOnly,
		Page:        int(in.Page),
		PageSize:    int(in.PageSize),
	})
	if err != nil {
		return nil, errorx.Internal(err.Error())
	}
	out := &super.AdminListMoeToolCallsResp{Total: total}
	for _, row := range rows {
		out.Items = append(out.Items, &super.AdminMoeToolCallItem{
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

func (l *MoeExecuteToolLogic) MoeExecuteTool(in *super.MoeExecuteToolReq) (*super.MoeExecuteToolResp, error) {
	deps := moeToolsDeps(l.ctx, l.svcCtx)
	tier := coreDefaultTier()
	botUID := uint(0)
	if in.AgentKey != "" {
		var rt model.MoeAgentRuntime
		if err := l.svcCtx.DB.Where("agent_key = ?", in.AgentKey).First(&rt).Error; err == nil {
			tier = parseCapabilityTier(rt.CapabilityTier)
			botUID = rt.BotUserID
		}
	}
	source := strings.TrimSpace(in.Source)
	if source == "" {
		source = "api"
	}
	start := time.Now()
	exec := tools.NewExecutor(deps)
	res := exec.Execute(l.ctx, coreExecuteRequest(in, tier, botUID))
	latency := int(time.Since(start).Milliseconds())
	toolaudit.Record(l.svcCtx.DB, toolaudit.RecordInput{
		Tool:           in.Tool,
		ArgumentsJSON:  in.ArgumentsJson,
		ActorUserID:    uint(in.ActorUserId),
		BotUserID:      botUID,
		AgentKey:       in.AgentKey,
		Ok:             res.OK,
		ErrorMsg:       res.Error,
		LatencyMs:      latency,
		Source:         source,
		IdempotencyKey: in.IdempotencyKey,
	})
	return &super.MoeExecuteToolResp{Ok: res.OK, Result: res.Result, Error: res.Error}, nil
}

type MoeSearchPostsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewMoeSearchPostsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *MoeSearchPostsLogic {
	return &MoeSearchPostsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *MoeSearchPostsLogic) MoeSearchPosts(in *super.MoeSearchPostsReq) (*super.MoeSearchPostsResp, error) {
	limit := int(in.Limit)
	if limit <= 0 {
		limit = 10
	}
	if limit > 30 {
		limit = 30
	}
	hits, err := postpulseKeywordSearch(l.ctx, l.svcCtx.DB, in, limit)
	if err != nil {
		return nil, errorx.Internal("检索失败")
	}
	out := &super.MoeSearchPostsResp{Total: int32(len(hits))}
	for _, h := range hits {
		out.Items = append(out.Items, &super.MoeSearchPostHit{
			PostId:      h.PostID,
			UserId:      h.UserID,
			UserName:    h.UserName,
			Content:     h.Content,
			Snippet:     h.Snippet,
			MoodTag:     h.MoodTag,
			Likes:       int32(h.Likes),
			Comments:    int32(h.Comments),
			CreatedAt:   h.CreatedAt,
			Score:       h.Score,
			ScoreReason: h.ScoreReason,
		})
	}
	return out, nil
}
