package runner

import (
	"context"
	"fmt"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

// HostInfo describes the machine running the Deploy Agent.
type HostInfo struct {
	OS           string `json:"os"`
	Arch         string `json:"arch"`
	Platform     string `json:"platform"`
	Shell        string `json:"shell"`
	HasMake      bool   `json:"has_make"`
	DockerCLI    string `json:"docker_cli"`
	ComposeCLI   string `json:"compose_cli"`
	GoVersion    string `json:"go_version"`
	DockerVersion string `json:"docker_version"`
	GitVersion   string `json:"git_version"`
	FlutterVersion string `json:"flutter_version"`
	WorkspaceRoot string `json:"workspace_root"`
	BackendDir   string `json:"backend_dir"`
	ComposeFile  string `json:"compose_file"`
}

// Platform wraps OS-specific command construction.
type Platform struct {
	backendDir  string
	composeFile string
	workspace   string
}

// NewPlatform creates a runner for the given paths.
func NewPlatform(workspace, backendDir, composeFile string) *Platform {
	return &Platform{
		workspace:   workspace,
		backendDir:  backendDir,
		composeFile: composeFile,
	}
}

// Inspect collects host capabilities.
func (p *Platform) Inspect(ctx context.Context) HostInfo {
	info := HostInfo{
		OS:            runtime.GOOS,
		Arch:          runtime.GOARCH,
		Platform:      platformLabel(),
		Shell:         shellLabel(),
		HasMake:       commandExists(ctx, "make"),
		WorkspaceRoot: p.workspace,
		BackendDir:    p.backendDir,
		ComposeFile:   p.composeFile,
	}
	info.DockerCLI, info.DockerVersion = dockerVersion(ctx)
	info.ComposeCLI = composeLabel(ctx)
	info.GoVersion = runOutput(ctx, p.backendDir, "go", "version")
	info.GitVersion = runOutput(ctx, p.workspace, "git", "--version")
	info.FlutterVersion = runOutput(ctx, p.workspace, "flutter", "--version")
	return info
}

func platformLabel() string {
	switch runtime.GOOS {
	case "darwin":
		return "macOS"
	case "windows":
		return "Windows"
	case "linux":
		return "Linux"
	default:
		return runtime.GOOS
	}
}

func shellLabel() string {
	if runtime.GOOS == "windows" {
		return "cmd.exe"
	}
	return "/bin/sh"
}

func commandExists(ctx context.Context, name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

// DockerAvailable reports whether docker CLI is on PATH.
func DockerAvailable() bool {
	return commandExists(context.Background(), "docker")
}

func dockerVersion(ctx context.Context) (cli string, version string) {
	if !commandExists(ctx, "docker") {
		return "", ""
	}
	version = strings.TrimSpace(runOutput(ctx, "", "docker", "--version"))
	if usesDockerComposeV2(ctx) {
		return "docker", version
	}
	return "docker", version
}

func composeLabel(ctx context.Context) string {
	if !commandExists(ctx, "docker") {
		return "unavailable"
	}
	if usesDockerComposeV2(ctx) {
		return "docker compose"
	}
	if commandExists(ctx, "docker-compose") {
		return "docker-compose"
	}
	return "unavailable"
}

func usesDockerComposeV2(ctx context.Context) bool {
	cmd := exec.CommandContext(ctx, "docker", "compose", "version")
	cmd.Stderr = nil
	return cmd.Run() == nil
}

func runOutput(ctx context.Context, dir string, name string, args ...string) string {
	cmd := exec.CommandContext(ctx, name, args...)
	if dir != "" {
		cmd.Dir = dir
	}
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

// CommandSpec is a resolved shell command (local or via SSH).
type CommandSpec struct {
	Dir       string
	Label     string
	Argv      []string
	Shell     bool
	ShellLine string
	SSH       *SSHConfig
}

// BuildLinuxCommand cross-compiles api+rpc for Linux amd64.
func (p *Platform) BuildLinuxCommand() CommandSpec {
	if commandExists(context.Background(), "make") {
		return p.shellInBackend("make build-linux", "make", "build-linux")
	}
	return p.goBuildLinux()
}

// BuildLocalCommand builds api+rpc for current OS.
func (p *Platform) BuildLocalCommand() CommandSpec {
	if commandExists(context.Background(), "make") {
		return p.shellInBackend("make build", "make", "build")
	}
	return p.goBuildLocal()
}

func (p *Platform) goBuildLinux() CommandSpec {
	script := buildGoLinuxScript(runtime.GOOS)
	return CommandSpec{
		Dir:       p.backendDir,
		Label:     "go build (linux amd64)",
		Shell:     true,
		ShellLine: script,
	}
}

func (p *Platform) goBuildLocal() CommandSpec {
	script := buildGoLocalScript(runtime.GOOS)
	return CommandSpec{
		Dir:       p.backendDir,
		Label:     "go build (local)",
		Shell:     true,
		ShellLine: script,
	}
}

func buildGoLinuxScript(goos string) string {
	const tpl = `CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o api/moe-social-api ./api && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o rpc/moe-social-rpc ./rpc`
	if goos == "windows" {
		return `set CGO_ENABLED=0&& set GOOS=linux&& set GOARCH=amd64&& go build -o api/moe-social-api ./api && set CGO_ENABLED=0&& set GOOS=linux&& set GOARCH=amd64&& go build -o rpc/moe-social-rpc ./rpc`
	}
	return tpl
}

func buildGoLocalScript(goos string) string {
	const tpl = `go build -o api/moe-social-api ./api && go build -o rpc/moe-social-rpc ./rpc`
	if goos == "windows" {
		return tpl
	}
	return tpl
}

// ComposePs returns docker compose ps.
func (p *Platform) ComposePs() CommandSpec {
	return p.compose("docker ps", "ps")
}

// ComposeUp returns docker compose up -d --build.
func (p *Platform) ComposeUp() CommandSpec {
	return p.compose("docker up", "up", "-d", "--build")
}

// ComposeStop returns docker compose stop.
func (p *Platform) ComposeStop() CommandSpec {
	return p.compose("docker stop", "stop")
}

// ComposeDown returns docker compose down.
func (p *Platform) ComposeDown() CommandSpec {
	return p.compose("docker down", "down")
}

// ComposeRestart restarts one or all services.
func (p *Platform) ComposeRestart(service string) CommandSpec {
	svc := strings.TrimSpace(service)
	if svc == "" || svc == "all" {
		return p.compose("docker restart all", "restart")
	}
	return p.compose("docker restart "+svc, "restart", svc)
}

// DockerLogs tails container logs.
func (p *Platform) DockerLogs(service string, tail int) CommandSpec {
	name := containerName(service)
	if tail <= 0 {
		tail = 100
	}
	return CommandSpec{
		Dir:     p.backendDir,
		Label:   "docker logs " + name,
		Argv:    []string{"docker", "logs", "--tail", fmt.Sprintf("%d", tail), name},
		Shell:   false,
	}
}

func containerName(service string) string {
	switch strings.ToLower(strings.TrimSpace(service)) {
	case "rpc":
		return "moe-social-rpc"
	case "api", "":
		return "moe-social-api"
	default:
		return service
	}
}

func (p *Platform) compose(label string, args ...string) CommandSpec {
	if usesDockerComposeV2(context.Background()) {
		argv := append([]string{"docker", "compose", "-f", p.composeFile}, args...)
		return CommandSpec{
			Dir:   p.backendDir,
			Label: label,
			Argv:  argv,
		}
	}
	argv := append([]string{"docker-compose", "-f", p.composeFile}, args...)
	return CommandSpec{
		Dir:   p.backendDir,
		Label: label,
		Argv:  argv,
	}
}

func (p *Platform) shellInBackend(line string, argv ...string) CommandSpec {
	if runtime.GOOS == "windows" && len(argv) == 0 {
		return CommandSpec{Dir: p.backendDir, Label: line, Shell: true, ShellLine: line}
	}
	if len(argv) > 0 {
		return CommandSpec{Dir: p.backendDir, Label: line, Argv: argv}
	}
	return CommandSpec{Dir: p.backendDir, Label: line, Shell: true, ShellLine: line}
}

// EnvInspectCommand prints go env in backend dir.
func (p *Platform) EnvInspectCommand() CommandSpec {
	if commandExists(context.Background(), "make") {
		return p.shellInBackend("make env-status", "make", "env-status")
	}
	return CommandSpec{
		Dir:   p.backendDir,
		Label: "go env",
		Argv:  []string{"go", "env", "GOOS", "GOARCH", "CGO_ENABLED"},
	}
}

// FlutterPubGet runs flutter pub get at workspace root (login shell + ANDROID_HOME).
func (p *Platform) FlutterPubGet() CommandSpec {
	return flutterShellCommand(p.workspace, "flutter pub get")
}

// FlutterBuildAPK builds release APK (local machine only).
func (p *Platform) FlutterBuildAPK(versionName string) CommandSpec {
	v := strings.TrimSpace(versionName)
	line := "flutter build apk --release --no-tree-shake-icons"
	if v != "" {
		line += " --build-name " + shellQuote(v)
	}
	return flutterShellCommand(p.workspace, line)
}

// GitTags lists tags in workspace.
func (p *Platform) GitTags() CommandSpec {
	return CommandSpec{
		Dir:   p.workspace,
		Label: "git tag",
		Argv:  []string{"git", "tag", "--sort=-creatordate"},
	}
}

// ResolvePath ensures path exists under workspace (safety).
func (p *Platform) ResolvePath(rel string) (string, error) {
	if filepath.IsAbs(rel) {
		return rel, nil
	}
	return filepath.Join(p.workspace, rel), nil
}
