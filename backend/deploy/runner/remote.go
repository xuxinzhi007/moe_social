package runner

import (
	"context"
	"fmt"
	"strings"

	deploycfg "backend/deploy/config"
)

// RemotePlatform runs Linux shell commands on a cloud host via SSH.
type RemotePlatform struct {
	Target deploycfg.DeployTarget
}

// NewRemotePlatform creates a remote executor.
func NewRemotePlatform(t deploycfg.DeployTarget) *RemotePlatform {
	return &RemotePlatform{Target: t}
}

// SSHLabel returns display name for logs.
func (r *RemotePlatform) SSHLabel() string {
	return fmt.Sprintf("ssh %s@%s:%d", r.Target.User, r.Target.Host, r.Target.Port)
}

// ResolveCommand maps job type to remote shell (always Linux on VPS).
func (r *RemotePlatform) ResolveCommand(req JobRequest) (CommandSpec, error) {
	if IsLocalOnlyJob(req.Type) {
		return CommandSpec{}, fmt.Errorf("任务 %s 仅能在本机 (local) 执行", req.Type)
	}
	t := strings.TrimSpace(strings.ToLower(req.Type))
	params := req.Params
	if params == nil {
		params = map[string]string{}
	}
	be := r.Target.BackendDir
	cf := r.Target.ComposeFile
	if be == "" {
		return CommandSpec{}, fmt.Errorf("远程 target 未配置 backend_dir")
	}
	if cf == "" {
		cf = "docker-compose.binary.yml"
	}

	var script string
	var label string
	switch t {
	case "env_inspect":
		label = "remote env"
		script = fmt.Sprintf("cd %s && go env GOOS GOARCH CGO_ENABLED 2>/dev/null; docker --version; docker compose version 2>/dev/null || docker-compose --version", shellQuote(be))
	case "backend_build_linux":
		label = "remote build-linux"
		script = fmt.Sprintf("cd %s && (make build-linux 2>/dev/null || (CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o api/moe-social-api ./api && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o rpc/moe-social-rpc ./rpc))", shellQuote(be))
	case "backend_build_local":
		label = "remote build"
		script = fmt.Sprintf("cd %s && (make build 2>/dev/null || (go build -o api/moe-social-api ./api && go build -o rpc/moe-social-rpc ./rpc))", shellQuote(be))
	case "docker_ps":
		label = "remote docker ps"
		script = r.composeScriptWithContainerFallback(cf, "ps")
	case "docker_up":
		label = "remote docker up"
		script = r.composeScript(cf, "up", "-d", "--build")
	case "docker_stop":
		label = "remote docker stop"
		script = r.composeScript(cf, "stop")
	case "docker_down":
		label = "remote docker down"
		script = r.composeScript(cf, "down")
	case "docker_restart":
		svc := strings.TrimSpace(params["service"])
		label = "remote docker restart"
		if svc == "" || svc == "all" {
			script = r.composeScript(cf, "restart")
		} else {
			script = r.composeScript(cf, "restart", svc)
		}
	case "docker_logs":
		name := containerName(params["service"])
		tail := params["tail"]
		if tail == "" {
			tail = "100"
		}
		label = "remote docker logs"
		script = fmt.Sprintf("docker logs --tail %s %s", shellQuote(tail), shellQuote(name))
	case "remote_inspect":
		label = "remote path inspect"
		script = RemoteInspectScript(be, cf)
	default:
		return CommandSpec{}, fmt.Errorf("unknown job type: %s", req.Type)
	}

	return CommandSpec{
		Label:     label + " @ " + r.SSHLabel(),
		Shell:     true,
		ShellLine: script,
		SSH:       r.sshConfig(),
	}, nil
}

func (r *RemotePlatform) composeScript(composeFile string, args ...string) string {
	be := shellQuote(r.Target.BackendDir)
	cf := shellQuote(composeFile)
	argStr := strings.Join(args, " ")
	return fmt.Sprintf(
		"cd %s && (docker compose -f %s %s || docker-compose -f %s %s)",
		be, cf, argStr, cf, argStr,
	)
}

// composeScriptWithContainerFallback runs compose in backend_dir; if path missing, lists moe-social-* containers.
func (r *RemotePlatform) composeScriptWithContainerFallback(composeFile string, args ...string) string {
	be := shellQuote(r.Target.BackendDir)
	cf := shellQuote(composeFile)
	argStr := strings.Join(args, " ")
	return fmt.Sprintf(
		`if [ -d %s ] && [ -f %s/%s ]; then %s; else echo "=== compose 目录不可用 (%s)，按容器名查看 moe-social-api / moe-social-rpc ==="; docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -E '^(NAMES|moe-social-api|moe-social-rpc)'; fi`,
		be, be, composeFile,
		fmt.Sprintf("cd %s && (docker compose -f %s %s || docker-compose -f %s %s)", be, cf, argStr, cf, argStr),
		r.Target.BackendDir,
	)
}

func (r *RemotePlatform) sshConfig() *SSHConfig {
	return &SSHConfig{
		Host:         r.Target.Host,
		Port:         r.Target.Port,
		User:         r.Target.User,
		IdentityFile: r.Target.IdentityFile,
		Password:     r.Target.Password,
	}
}

// Inspect runs lightweight remote probes via SSH.
func (r *RemotePlatform) Inspect(ctx context.Context) HostInfo {
	script := "uname -srmo 2>/dev/null; docker --version 2>/dev/null; docker compose version 2>/dev/null | head -1"
	spec := CommandSpec{
		Label:     "ssh inspect",
		Shell:     true,
		ShellLine: script,
		SSH:       r.sshConfig(),
	}
	out, _, _ := RunCapture(ctx, spec)
	lines := strings.Split(strings.TrimSpace(out), "\n")
	info := HostInfo{
		OS:            "linux",
		Arch:          "remote",
		Platform:      "云平台 SSH",
		Shell:         "ssh → /bin/sh",
		WorkspaceRoot: r.Target.BackendDir,
		BackendDir:    r.Target.BackendDir,
		ComposeFile:   r.Target.ComposeFile,
		ComposeCLI:    "docker compose (remote)",
	}
	if len(lines) > 0 {
		info.Platform = "云平台 · " + lines[0]
	}
	if len(lines) > 1 {
		info.DockerVersion = lines[1]
	}
	if len(lines) > 2 {
		info.ComposeCLI = lines[2]
	}
	return info
}

// IsLocalOnlyJob types that must run on the agent machine (Mac/Windows).
func IsLocalOnlyJob(jobType string) bool {
	switch strings.TrimSpace(strings.ToLower(jobType)) {
	case "flutter_pub_get", "flutter_build_apk", "flutter_doctor",
		"backend_build_linux", "backend_build_local", "env_inspect", "git_tags":
		return true
	default:
		return false
	}
}

// IsCloudOnlyJob types that must run on SSH cloud target (Docker on VPS).
func IsCloudOnlyJob(jobType string) bool {
	switch strings.TrimSpace(strings.ToLower(jobType)) {
	case "docker_ps", "docker_up", "docker_stop", "docker_down", "docker_restart", "docker_logs", "remote_inspect",
		"backend_upload_binaries":
		return true
	default:
		return false
	}
}

// SuggestedTarget picks local vs cloud from job type; keeps explicit choice for GitHub jobs.
func SuggestedTarget(jobType, requested string) string {
	t := strings.TrimSpace(strings.ToLower(jobType))
	if IsCloudOnlyJob(t) {
		if strings.TrimSpace(requested) != "" {
			return requested
		}
		return "cloud"
	}
	if IsLocalOnlyJob(t) {
		return "local"
	}
	if strings.TrimSpace(requested) != "" {
		return requested
	}
	return "local"
}
