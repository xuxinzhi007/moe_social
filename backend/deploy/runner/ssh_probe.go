package runner

import (
	"context"
	"fmt"
	"strings"

	deploycfg "backend/deploy/config"
)

// SSHProbeResult describes SSH connectivity to a target.
type SSHProbeResult struct {
	OK       bool   `json:"ok"`
	Message  string `json:"message"`
	Command  string `json:"command"`
	Output   string `json:"output"`
	ExitCode int    `json:"exit_code"`
}

// ProbeSSH runs a short non-interactive SSH test.
func ProbeSSH(ctx context.Context, cfg *deploycfg.Config, targetID string) SSHProbeResult {
	t := cfg.TargetByID(targetID)
	if !t.IsSSH() {
		return SSHProbeResult{OK: false, Message: "目标不是 SSH 远程环境"}
	}
	rp := NewRemotePlatform(t)
	script := "echo MOE_SSH_OK && hostname && docker --version 2>/dev/null | head -1"
	spec := CommandSpec{
		Label:     "ssh probe",
		Shell:     true,
		ShellLine: script,
		SSH:       rp.sshConfig(),
	}
	out, code, err := RunCapture(ctx, spec)
	res := SSHProbeResult{
		Command:  DisplayCommand(spec),
		Output:   strings.TrimSpace(out),
		ExitCode: code,
	}
	if err != nil {
		res.Message = err.Error()
		return res
	}
	if code != 0 {
		res.Message = sshFailureHint(code, t.User, t.Host, out)
		return res
	}
	if !strings.Contains(out, "MOE_SSH_OK") {
		res.Message = "SSH 已连接但输出异常"
		return res
	}
	res.OK = true
	res.Message = "SSH 连通，可在云平台执行 Docker"
	return res
}

func sshFailureHint(exitCode int, user, host, output string) string {
	lower := strings.ToLower(output)
	switch {
	case strings.Contains(lower, "permission denied"):
		return fmt.Sprintf(
			"SSH 认证失败（exit=%d）：请在 deploy/config.yaml 的 cloud 目标配置 identity_file（推荐 ssh-copy-id）或 password；本机终端也需能登录 ssh %s@%s",
			exitCode, user, host,
		)
	case strings.Contains(lower, "connection refused"), strings.Contains(lower, "timed out"), strings.Contains(lower, "no route"):
		return fmt.Sprintf("SSH 无法连接 %s@%s（exit=%d）：检查 IP、安全组 22 端口与 VPS 是否开机", user, host, exitCode)
	default:
		return fmt.Sprintf("SSH 失败 exit=%d；可先在本机执行 ssh %s@%s 排查", exitCode, user, host)
	}
}
