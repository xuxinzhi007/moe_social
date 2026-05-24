package runner

import (
	"context"
	"fmt"
	"strings"

	deploycfg "backend/deploy/config"
)

// Registry resolves job execution per deploy target.
type Registry struct {
	Local  *Platform
	Remote map[string]*RemotePlatform
}

// NewRegistry builds executors from config.
func NewRegistry(cfg *deploycfg.Config) *Registry {
	if mode, bash := cfg.ResolvedWindowsShell(); mode != "" {
		InitWindowsShell(mode, bash)
	}
	InitLocalPathExtra(cfg.LocalPathExtra)
	SetDeployBuildCacheRoot(cfg.BuildCacheAbs())
	reg := &Registry{
		Local: NewPlatform(cfg.WorkspaceAbs(), cfg.BackendAbs(), cfg.ComposeFileAbs()),
		Remote: make(map[string]*RemotePlatform),
	}
	for _, t := range cfg.NormalizeTargets() {
		if t.IsSSH() && t.ID != "" {
			reg.Remote[t.ID] = NewRemotePlatform(t)
		}
	}
	return reg
}

// ResolveCommand picks local or remote platform.
func (reg *Registry) ResolveCommand(targetID string, cfg *deploycfg.Config, req JobRequest) (CommandSpec, error) {
	targetID = SuggestedTarget(req.Type, targetID)
	t := cfg.TargetByID(targetID)
	jobType := strings.TrimSpace(strings.ToLower(req.Type))

	if IsLocalOnlyJob(jobType) && t.IsSSH() {
		return CommandSpec{}, fmt.Errorf("任务 %s 仅在本机 (local) 执行：Flutter/后端编译在 Mac 上，不在 VPS", req.Type)
	}
	if IsCloudOnlyJob(jobType) && !t.IsSSH() {
		return CommandSpec{}, fmt.Errorf(
			"任务 %s 应在云平台 (cloud) 执行：Docker 在 VPS 上，请切换顶部「云平台」目标",
			req.Type,
		)
	}
	if t.IsSSH() {
		rp, ok := reg.Remote[t.ID]
		if !ok {
			return CommandSpec{}, fmt.Errorf(
				"未配置远程目标「%s」：请在 deploy/config.yaml 的 targets 中加入 cloud SSH（参考 config.example.yaml）",
				t.ID,
			)
		}
		return rp.ResolveCommand(req)
	}
	if strings.HasPrefix(jobType, "docker") && !DockerAvailable() {
		return CommandSpec{}, fmt.Errorf(
			"本机未检测到 Docker。容器编排请使用云平台 (cloud) 目标",
		)
	}
	return reg.Local.ResolveCommand(req)
}

// InspectHost returns host info for target.
func (reg *Registry) InspectHost(ctx context.Context, targetID string, cfg *deploycfg.Config) HostInfo {
	t := cfg.TargetByID(targetID)
	if t.IsSSH() {
		if rp, ok := reg.Remote[t.ID]; ok {
			return rp.Inspect(ctx)
		}
	}
	return reg.Local.InspectLocal(ctx)
}

// ComposePsSpec for docker status on target.
func (reg *Registry) ComposePsSpec(targetID string, cfg *deploycfg.Config) (CommandSpec, error) {
	return reg.ResolveCommand(targetID, cfg, JobRequest{Type: "docker_ps"})
}
