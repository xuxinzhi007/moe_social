package runner

import (
	"context"
	"fmt"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
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

// InspectLocal probes the dev machine for cross-compile / Flutter (matches Moe Ops HTML 本机卡片).
// Intentionally skips Docker: local packaging uses go build in backend/; Docker is cloud-only.
func (p *Platform) InspectLocal(ctx context.Context) HostInfo {
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
	info.GoVersion = runOutput(ctx, p.backendDir, "go", "version")
	if path, err := exec.LookPath("flutter"); err == nil {
		info.FlutterVersion = runOutput(ctx, p.workspace, path, "--version")
	}
	return info
}

// Inspect collects full host capabilities including Docker (slower; avoid for target=local).
func (p *Platform) Inspect(ctx context.Context) HostInfo {
	info := p.InspectLocal(ctx)
	info.DockerCLI, info.DockerVersion = dockerVersion(ctx)
	info.ComposeCLI = composeLabel(ctx)
	info.GitVersion = runOutput(ctx, p.workspace, "git", "--version")
	return info
}

const inspectProbeTimeout = 6 * time.Second

func probeCtx(ctx context.Context) (context.Context, context.CancelFunc) {
	return context.WithTimeout(ctx, inspectProbeTimeout)
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
		if _, _, label := WindowsShellInfo(); label != "" {
			return label
		}
		return "cmd.exe"
	}
	return "/bin/sh"
}

func commandExists(ctx context.Context, name string) bool {
	if _, err := exec.LookPath(name); err == nil {
		return true
	}
	if runtime.GOOS == "windows" && useGitBashOnWindows() {
		return runGitBashCapture(ctx, "command -v "+name) != ""
	}
	return false
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
	pctx, cancel := probeCtx(ctx)
	defer cancel()
	cmd := exec.CommandContext(pctx, "docker", "compose", "version")
	cmd.Stderr = nil
	return cmd.Run() == nil
}

func runOutput(ctx context.Context, dir string, name string, args ...string) string {
	pctx, cancel := probeCtx(ctx)
	defer cancel()
	cmd := exec.CommandContext(pctx, name, args...)
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
	// LinuxCrossBuild runs go build with GOOS=linux via exec.Env（不依赖 make / shell 环境变量写法）
	LinuxCrossBuild bool
}

// BuildLinuxCommand cross-compiles api+rpc for Linux amd64.
// Agent 统一用 go 子进程 + 环境变量，避免 Windows 上 make/cmd 无法解析 Makefile 里的 Unix 写法。
func (p *Platform) BuildLinuxCommand() CommandSpec {
	return CommandSpec{
		Dir:             p.backendDir,
		Label:           "go build (linux amd64)",
		LinuxCrossBuild: true,
	}
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
	const tpl = `CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/moe-social ./cmd/moe-social`
	if goos == "windows" && !useGitBashOnWindows() {
		return `set CGO_ENABLED=0&& set GOOS=linux&& set GOARCH=amd64&& go build -o bin/moe-social ./cmd/moe-social`
	}
	return tpl
}

func buildGoLocalScript(goos string) string {
	return `go build -o bin/moe-social ./cmd/moe-social`
}

func containerName(service string) string {
	switch strings.ToLower(strings.TrimSpace(service)) {
	case "api", "rpc", "", "moe-social", "moe":
		return "moe-social"
	default:
		return service
	}
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

// LearningEnvCheckCommand verifies Python + optional ollama_web finetune checkout.
func (p *Platform) LearningEnvCheckCommand() CommandSpec {
	script := filepath.Join(p.workspace, "tools", "character-finetune", "env_check.sh")
	return CommandSpec{
		Dir:   p.workspace,
		Label: "learning env check",
		Argv:  []string{"bash", script},
	}
}

// LearningTrainLoraCommand runs LoRA training via tools/character-finetune (params: dataset_path, output_dir, finetune_dir).
func (p *Platform) LearningTrainLoraCommand(params map[string]string) CommandSpec {
	script := filepath.Join(p.workspace, "tools", "character-finetune", "run_train.sh")
	argv := []string{"bash", script}
	if v := strings.TrimSpace(params["dataset_path"]); v != "" {
		argv = append(argv, "--dataset", v)
	}
	if v := strings.TrimSpace(params["output_dir"]); v != "" {
		argv = append(argv, "--output", v)
	}
	if v := strings.TrimSpace(params["finetune_dir"]); v != "" {
		argv = append(argv, "--finetune-dir", v)
	}
	return CommandSpec{
		Dir:   p.workspace,
		Label: "learning train lora",
		Argv:  argv,
	}
}

// ResolvePath ensures path exists under workspace (safety).
func (p *Platform) ResolvePath(rel string) (string, error) {
	if filepath.IsAbs(rel) {
		return rel, nil
	}
	return filepath.Join(p.workspace, rel), nil
}
