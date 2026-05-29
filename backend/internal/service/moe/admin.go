package moeadmin

import (
	"context"
	"errors"
	"strings"
	"time"

	moebiz "backend/internal/biz/moe"
	moedata "backend/internal/data/moe"
	"backend/model"
	"backend/pkg/moe/brain"
	"backend/pkg/moe/port"
	"backend/pkg/moe/postpulse"
	"backend/pkg/moe/runtime"
	"backend/pkg/moe/toolaudit"
	"backend/pkg/moe/tools"

	"gorm.io/gorm"
)

// AdminService Moe 管理端应用服务（Kratos service 层，混合期由 go-zero RPC 调用）。
type AdminService struct {
	db              *gorm.DB
	store           moebiz.MoeStore
	runtimeDeps     RuntimeDepsFactory
	moeToolPort     MoeToolPortFactory
	brainDeps       BrainDepsFactory
	brainRefineDeps BrainRefineDepsFactory
	toolsDeps       ToolsDepsFactory
}

// NewAdmin 构造 AdminService。
func NewAdmin(db *gorm.DB) *AdminService {
	return &AdminService{db: db, store: moedata.NewStore(db)}
}

// AttachRuntimeDeps 注入试跑/调度所需的 runtime 依赖（RPC 启动时调用一次）。
func (s *AdminService) AttachRuntimeDeps(fn RuntimeDepsFactory) {
	s.runtimeDeps = fn
}

// AttachMoeToolPort 注入 Moe 工具 RPC 端口（RPC 启动时调用一次）。
func (s *AdminService) AttachMoeToolPort(fn MoeToolPortFactory) {
	s.moeToolPort = fn
}

// AttachBrainDeps 注入 brain.Deps。
func (s *AdminService) AttachBrainDeps(fn BrainDepsFactory) {
	s.brainDeps = fn
}

// AttachBrainRefineDeps 注入 brain.RefineDeps。
func (s *AdminService) AttachBrainRefineDeps(fn BrainRefineDepsFactory) {
	s.brainRefineDeps = fn
}

// AttachToolsDeps 注入 tools.Deps。
func (s *AdminService) AttachToolsDeps(fn ToolsDepsFactory) {
	s.toolsDeps = fn
}

func (s *AdminService) requireRuntimeDeps(ctx context.Context) (runtime.Deps, error) {
	if s.runtimeDeps == nil {
		return runtime.Deps{}, errors.New("moe admin: runtime deps 未注入")
	}
	deps := s.runtimeDeps(ctx)
	if deps.DB == nil {
		deps.DB = s.db
	}
	return deps, nil
}

func (s *AdminService) requireMoeToolPort(ctx context.Context) (port.MoeToolPort, error) {
	if s.moeToolPort == nil {
		return nil, errors.New("moe admin: moe tool port 未注入")
	}
	return s.moeToolPort(ctx), nil
}

func (s *AdminService) requireBrainDeps(ctx context.Context) (brain.Deps, error) {
	if s.brainDeps == nil {
		return brain.Deps{}, errors.New("moe admin: brain deps 未注入")
	}
	deps := s.brainDeps(ctx)
	if deps.DB == nil {
		deps.DB = s.db
	}
	return deps, nil
}

func (s *AdminService) requireBrainRefineDeps(ctx context.Context) (brain.RefineDeps, error) {
	if s.brainRefineDeps == nil {
		return brain.RefineDeps{}, errors.New("moe admin: brain refine deps 未注入")
	}
	deps := s.brainRefineDeps(ctx)
	if deps.DB == nil {
		deps.DB = s.db
	}
	return deps, nil
}

func (s *AdminService) requireToolsDeps(ctx context.Context) (tools.Deps, error) {
	if s.toolsDeps == nil {
		return tools.Deps{}, errors.New("moe admin: tools deps 未注入")
	}
	deps := s.toolsDeps(ctx)
	if deps.DB == nil {
		deps.DB = s.db
	}
	return deps, nil
}

// GetBrainPipeline 查询试跑流水线快照。
func (s *AdminService) GetBrainPipeline(ctx context.Context, agentKey string) (moebiz.PipelineSnapshot, error) {
	return moebiz.GetBrainPipeline(ctx, s.store, agentKey)
}

// GetBotFlowConfig 读取 Bot 编排画布配置。
func (s *AdminService) GetBotFlowConfig(ctx context.Context, agentKey string) (moebiz.FlowConfig, error) {
	return moebiz.GetFlowConfig(ctx, s.store, agentKey)
}

// UpsertBotFlowConfig 保存 Bot 编排画布配置。
func (s *AdminService) UpsertBotFlowConfig(ctx context.Context, agentKey string, in moebiz.FlowConfig) (moebiz.FlowConfig, error) {
	return moebiz.UpsertFlowConfig(ctx, s.store, agentKey, in)
}

// DeleteBotFlowConfig 重置为默认画布模板。
func (s *AdminService) DeleteBotFlowConfig(ctx context.Context, agentKey string) (moebiz.FlowConfig, error) {
	return moebiz.DeleteFlowConfig(ctx, s.store, agentKey)
}

// RunOnceInvokeResult 试跑调用结果（同步完成或异步已接受）。
type RunOnceInvokeResult struct {
	Result         runtime.RunOnceResult
	Accepted       bool
	AlreadyRunning bool
}

// RunAgentOnce 执行一次 Bot 试跑；async=true 时立即返回并在后台执行。
func (s *AdminService) RunAgentOnce(ctx context.Context, agentKey string, async bool) (RunOnceInvokeResult, error) {
	if async {
		deps, err := s.requireRuntimeDeps(ctx)
		if err != nil {
			return RunOnceInvokeResult{}, err
		}
		start, err := moebiz.RunAgentOnceAsync(ctx, deps, agentKey)
		if err != nil {
			return RunOnceInvokeResult{}, err
		}
		return RunOnceInvokeResult{Accepted: start.Accepted, AlreadyRunning: start.AlreadyRunning}, nil
	}
	deps, err := s.requireRuntimeDeps(ctx)
	if err != nil {
		return RunOnceInvokeResult{}, err
	}
	res, err := moebiz.RunAgentOnce(ctx, deps, agentKey)
	if err != nil {
		return RunOnceInvokeResult{}, err
	}
	return RunOnceInvokeResult{Result: res}, nil
}

// GetBrainSnapshot 加载大脑观测快照。
func (s *AdminService) GetBrainSnapshot(ctx context.Context, agentKey string) (*brain.Snapshot, error) {
	rpc, err := s.requireMoeToolPort(ctx)
	if err != nil {
		return nil, err
	}
	return moebiz.GetBrainSnapshot(ctx, s.store, rpc, agentKey)
}

// UpdateBrainPolicy 更新标签策略并返回最新快照。
func (s *AdminService) UpdateBrainPolicy(ctx context.Context, agentKey string, forbiddenTags, preferredTags []string) (*brain.Snapshot, error) {
	rpc, err := s.requireMoeToolPort(ctx)
	if err != nil {
		return nil, err
	}
	return moebiz.UpdateBrainPolicy(ctx, s.store, rpc, agentKey, forbiddenTags, preferredTags)
}

// ListRuntimes 列出 Bot 运行时。
func (s *AdminService) ListRuntimes(ctx context.Context) ([]model.MoeAgentRuntime, error) {
	return moebiz.ListRuntimes(ctx, s.store)
}

// FindRuntimeByAgentKey 按 agent_key 查找运行时。
func (s *AdminService) FindRuntimeByAgentKey(ctx context.Context, agentKey string) (*model.MoeAgentRuntime, error) {
	agentKey = strings.TrimSpace(agentKey)
	if agentKey == "" {
		return nil, nil
	}
	rows, err := s.ListRuntimes(ctx)
	if err != nil {
		return nil, err
	}
	for i := range rows {
		if rows[i].AgentKey == agentKey {
			return &rows[i], nil
		}
	}
	return nil, nil
}

// UpsertRuntime 创建或更新 Bot 运行时。
func (s *AdminService) UpsertRuntime(ctx context.Context, p moebiz.UpsertRuntimeParams) (model.MoeAgentRuntime, error) {
	return moebiz.UpsertRuntime(ctx, s.store, p)
}

// DeleteBrainEpisode 删除自传 episode。
func (s *AdminService) DeleteBrainEpisode(ctx context.Context, episodeID uint) error {
	deps, err := s.requireBrainDeps(ctx)
	if err != nil {
		return err
	}
	return moebiz.DeleteBrainEpisode(ctx, deps, episodeID)
}

// RefineBrainEpisode 润色单条 episode。
func (s *AdminService) RefineBrainEpisode(ctx context.Context, episodeID uint, opts brain.RefineOptions) (brain.RefineResult, error) {
	deps, err := s.requireBrainRefineDeps(ctx)
	if err != nil {
		return brain.RefineResult{}, err
	}
	return moebiz.RefineBrainEpisode(ctx, deps, episodeID, opts)
}

// CurateBrain 批量润色低质量 episode。
func (s *AdminService) CurateBrain(ctx context.Context, agentKey string, opts brain.CurateOptions) ([]brain.RefineResult, error) {
	deps, err := s.requireBrainRefineDeps(ctx)
	if err != nil {
		return nil, err
	}
	return moebiz.CurateBrain(ctx, deps, agentKey, opts)
}

// QueryToolStats 工具调用统计。
func (s *AdminService) QueryToolStats(ctx context.Context, f moebiz.ToolStatsFilter) (moebiz.ToolStatsResult, error) {
	return moebiz.QueryToolStats(ctx, s.store, f)
}

// ListToolCalls 工具调用列表。
func (s *AdminService) ListToolCalls(ctx context.Context, f moebiz.ToolCallsFilter) ([]moebiz.ToolCallRow, int64, error) {
	return moebiz.ListToolCalls(ctx, s.store, f)
}

// ExecuteTool 执行 Moe 工具。
func (s *AdminService) ExecuteTool(ctx context.Context, in moebiz.ExecuteToolInput) (moebiz.ExecuteToolResult, error) {
	deps, err := s.requireToolsDeps(ctx)
	if err != nil {
		return moebiz.ExecuteToolResult{}, err
	}
	return moebiz.ExecuteTool(ctx, s.store, deps, in), nil
}

// SearchPosts 检索社区帖子。
func (s *AdminService) SearchPosts(ctx context.Context, in moebiz.SearchPostsInput) ([]postpulse.SearchHit, error) {
	return moebiz.SearchPosts(ctx, s.store, in)
}

// ParseTimeFilter 解析管理端时间筛选（透传 toolaudit）。
func ParseTimeFilter(raw string, endOfDay bool) *time.Time {
	return toolaudit.ParseTimeFilter(raw, endOfDay)
}
