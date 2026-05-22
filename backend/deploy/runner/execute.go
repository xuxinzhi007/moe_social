package runner

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
)

// SSHConfig SSH connection for remote jobs.
type SSHConfig struct {
	Host         string
	Port         int
	User         string
	IdentityFile string
	Password     string // 可选；配置后走原生 SSH 客户端（可密码登录）
}

// LogSink receives stdout/stderr lines.
type LogSink func(line string)

// Execute runs a command spec and streams output to sink.
func Execute(ctx context.Context, spec CommandSpec, sink LogSink) (exitCode int, err error) {
	if spec.SSH != nil {
		cfg := *spec.SSH
		// 统一走原生 SSH（支持 password / 自动发现 ~/.ssh 密钥），避免 BatchMode 无法输密码
		return runSSHNative(ctx, cfg, spec.ShellLine, sink)
	}
	return runCommand(ctx, spec, sink)
}

func buildSSHCommandSpec(ssh SSHConfig, remoteScript string) (CommandSpec, error) {
	if strings.TrimSpace(remoteScript) == "" {
		return CommandSpec{}, fmt.Errorf("empty remote script")
	}
	port := ssh.Port
	if port <= 0 {
		port = 22
	}
	args := []string{
		"-p", strconv.Itoa(port),
		"-o", "BatchMode=yes",
		"-o", "ConnectTimeout=20",
		"-o", "StrictHostKeyChecking=accept-new",
	}
	if ssh.IdentityFile != "" {
		keyPath := ssh.IdentityFile
		if strings.HasPrefix(keyPath, "~/") {
			if home, err := os.UserHomeDir(); err == nil {
				keyPath = filepath.Join(home, keyPath[2:])
			}
		}
		args = append(args, "-i", keyPath)
	}
	args = append(args, fmt.Sprintf("%s@%s", ssh.User, ssh.Host), remoteScript)
	return CommandSpec{
		Label: "ssh",
		Argv:  append([]string{"ssh"}, args...),
	}, nil
}

func runCommand(ctx context.Context, spec CommandSpec, sink LogSink) (exitCode int, err error) {
	if spec.LinuxCrossBuild {
		return runLinuxCrossBuild(ctx, spec.Dir, sink)
	}
	var cmd *exec.Cmd
	if spec.Shell {
		cmd = shellCommand(ctx, spec.Dir, spec.ShellLine)
	} else if len(spec.Argv) > 0 {
		cmd = exec.CommandContext(ctx, spec.Argv[0], spec.Argv[1:]...)
		if spec.Dir != "" {
			cmd.Dir = spec.Dir
		}
	} else {
		return -1, fmt.Errorf("empty command")
	}
	workDir := spec.Dir
	if workDir == "" {
		workDir, _ = os.Getwd()
	}
	cmd.Env = BuildProcessEnv(workDir)
	cmd.Env = append(cmd.Env, "LANG=C", "LC_ALL=C")

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return -1, err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return -1, err
	}

	if sink != nil {
		if runtime.GOOS == "windows" && useGitBashOnWindows() {
			sink(fmt.Sprintf("# 本机 shell: Git Bash (%s)\n", windowsShellState.bashExe))
		} else if runtime.GOOS == "windows" {
			sink("# 本机 shell: cmd.exe（可在 config.yaml 设置 windows_shell: auto 使用 Git Bash）\n")
		}
		sink(fmt.Sprintf("$ %s\n", displayCommand(spec)))
	}

	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		pipeLines(commandOutputReader(stdout), sink)
	}()
	go func() {
		defer wg.Done()
		pipeLines(commandOutputReader(stderr), sink)
	}()

	if err := cmd.Start(); err != nil {
		return -1, err
	}
	wg.Wait()

	waitErr := cmd.Wait()
	exitCode = 0
	if waitErr != nil {
		if ee, ok := waitErr.(*exec.ExitError); ok {
			exitCode = ee.ExitCode()
		} else {
			return -1, waitErr
		}
	}
	return exitCode, nil
}

// DisplayCommand returns a human-readable command line.
func DisplayCommand(spec CommandSpec) string {
	return displayCommand(spec)
}

func displayCommand(spec CommandSpec) string {
	if spec.LinuxCrossBuild {
		return "go build -o api/moe-social-api ./api && go build -o rpc/moe-social-rpc ./rpc  (GOOS=linux GOARCH=amd64)"
	}
	if spec.SSH != nil {
		return fmt.Sprintf("ssh %s@%s %s", spec.SSH.User, spec.SSH.Host, spec.ShellLine)
	}
	if spec.Shell {
		return spec.ShellLine
	}
	if len(spec.Argv) > 0 {
		return strings.Join(spec.Argv, " ")
	}
	return spec.Label
}

func shellCommand(ctx context.Context, dir, line string) *exec.Cmd {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "windows":
		if useGitBashOnWindows() {
			cmd = exec.CommandContext(ctx, windowsShellState.bashExe, "-l", "-c", line)
		} else {
			cmd = exec.CommandContext(ctx, "cmd.exe", "/C", wrapWindowsCmd(line))
		}
	case "darwin":
		// 加载 ~/.zshrc，避免 flutter 找不到 Android SDK（Agent 子进程 PATH 过短）
		cmd = exec.CommandContext(ctx, "/bin/zsh", "-l", "-c", line)
	default:
		cmd = exec.CommandContext(ctx, "/bin/bash", "-l", "-c", line)
	}
	if dir != "" {
		cmd.Dir = dir
	}
	return cmd
}

func pipeLines(r io.Reader, sink LogSink) {
	if sink == nil {
		return
	}
	sc := bufio.NewScanner(r)
	buf := make([]byte, 0, 64*1024)
	sc.Buffer(buf, 1024*1024)
	for sc.Scan() {
		sink(sc.Text() + "\n")
	}
}

// RunCapture runs a command and returns combined output (for inspect).
func RunCapture(ctx context.Context, spec CommandSpec) (string, int, error) {
	var buf bytes.Buffer
	sink := func(line string) { buf.WriteString(line) }
	code, err := Execute(ctx, spec, sink)
	return buf.String(), code, err
}
