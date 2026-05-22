package runner

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	deploycfg "backend/deploy/config"

	"github.com/pkg/sftp"
)

const sftpUploadSuffix = ".uploading"

// IsUploadJob reports jobs that SFTP local binaries to the cloud target.
func IsUploadJob(jobType string) bool {
	return strings.TrimSpace(strings.ToLower(jobType)) == "backend_upload_binaries"
}

type binaryArtifact struct {
	localRel  string
	remoteRel string
}

var backendBinaryArtifacts = []binaryArtifact{
	{localRel: filepath.Join("api", "moe-social-api"), remoteRel: "api/moe-social-api"},
	{localRel: filepath.Join("rpc", "moe-social-rpc"), remoteRel: "rpc/moe-social-rpc"},
}

// RunBackendUpload copies Linux binaries from the local workspace to cloud via SFTP.
// Target must be an SSH cloud target; files are read from Registry.Local backend dir.
func (reg *Registry) RunBackendUpload(
	ctx context.Context,
	targetID string,
	cfg *deploycfg.Config,
	req JobRequest,
	sink LogSink,
) (exitCode int, err error) {
	targetID = SuggestedTarget(req.Type, targetID)
	t := cfg.TargetByID(targetID)
	if !t.IsSSH() {
		return 1, fmt.Errorf("backend_upload_binaries 需要云平台 (cloud) SSH 目标")
	}
	rp, ok := reg.Remote[t.ID]
	if !ok {
		return 1, fmt.Errorf("未配置远程目标 %q", t.ID)
	}
	if reg.Local == nil {
		return 1, fmt.Errorf("本地 workspace 未初始化")
	}

	stopBefore := parseStopBeforeParam(req.Params)
	restart := parseRestartParam(req.Params)
	cf := rp.Target.ComposeFile
	if cf == "" {
		cf = "docker-compose.binary.yml"
	}
	localBE := reg.Local.backendDir
	remoteBE := strings.TrimSuffix(strings.TrimSpace(rp.Target.BackendDir), "/")
	if remoteBE == "" {
		return 1, fmt.Errorf("远程 target 未配置 backend_dir")
	}

	stoppedContainers := false
	uploadSucceeded := false
	defer func() {
		if stoppedContainers && !uploadSucceeded {
			recoverContainersUp(ctx, rp, cf, restart.services, sink)
		}
	}()

	if sink != nil {
		sink("【1/6】准备上传（停止容器 → 传文件 → 再启动）\n")
		sink(fmt.Sprintf("  本机 backend: %s\n", localBE))
		sink(fmt.Sprintf("  远程 backend: %s@%s:%s\n", rp.Target.User, rp.Target.Host, remoteBE))
		for _, art := range backendBinaryArtifacts {
			sink(fmt.Sprintf("    %s → %s/%s\n", art.localRel, remoteBE, art.remoteRel))
		}
	}

	if stopBefore.enabled {
		if sink != nil {
			sink("【2/6】停止 api / rpc 容器（释放二进制占用）…\n")
		}
		stopScript := rp.composeScript(cf, append([]string{"stop"}, stopBefore.services...)...)
		if sink != nil {
			sink("$ " + stopScript + "\n")
		}
		code, err := runSSHNative(ctx, *rp.sshConfig(), stopScript, sink)
		if err != nil {
			return -1, err
		}
		if code != 0 {
			return code, fmt.Errorf("停止容器失败 exit=%d（可检查 VPS docker compose）", code)
		}
		stoppedContainers = true
	} else if sink != nil {
		sink("【2/6】跳过停止（params.stop_before=false）\n")
	}

	if sink != nil {
		sink("【4/6】并行上传 api + rpc（各用独立 SFTP 连接）…\n")
	}
	if err := uploadBinariesParallel(ctx, *rp.sshConfig(), localBE, remoteBE, sink); err != nil {
		if sink != nil {
			sink(fmt.Sprintf("上传失败: %v\n", err))
		}
		return 1, err
	}
	uploadSucceeded = true

	if !restart.enabled {
		if sink != nil {
			sink("【5/6】跳过启动（params.restart=false）；请手动 docker compose up\n")
			sink("【6/6】完成（仅上传，容器未启动）\n")
		}
		return 0, nil
	}

	if sink != nil {
		sink("【5/6】启动 api / rpc 容器（加载新二进制）…\n")
	}
	code, err := runComposeUp(ctx, rp, cf, restart.services, sink)
	if sink != nil {
		if err == nil && code == 0 {
			sink("【6/6】完成\n")
		} else {
			sink(fmt.Sprintf("【6/6】启动未成功 exit=%d\n", code))
		}
	}
	return code, err
}

// recoverContainersUp 在上传失败且曾停止容器后拉起服务，避免 VPS 长时间不可用（沿用磁盘上已有二进制）。
func recoverContainersUp(ctx context.Context, rp *RemotePlatform, composeFile string, services []string, sink LogSink) {
	if sink != nil {
		sink("\n【恢复】上传未完成，正在重新启动 api/rpc（使用 VPS 上当前文件，可能仍为旧版本）…\n")
	}
	code, err := runComposeUp(ctx, rp, composeFile, services, sink)
	if sink != nil {
		if err != nil {
			sink(fmt.Sprintf("【恢复】启动异常: %v\n", err))
			return
		}
		if code == 0 {
			sink("【恢复】容器已重新启动，服务应已恢复在线\n")
		} else {
			sink(fmt.Sprintf("【恢复】启动失败 exit=%d，请登录 VPS 手动 docker compose up -d\n", code))
		}
	}
}

func runComposeUp(ctx context.Context, rp *RemotePlatform, composeFile string, services []string, sink LogSink) (int, error) {
	var script string
	if len(services) == 0 {
		script = rp.composeScript(composeFile, "up", "-d")
	} else {
		args := append([]string{"up", "-d"}, services...)
		script = rp.composeScript(composeFile, args...)
	}
	if sink != nil {
		sink("$ " + script + "\n")
	}
	return runSSHNative(ctx, *rp.sshConfig(), script, sink)
}

type composeStepOption struct {
	enabled  bool
	services []string // empty = all services in compose file
}

func parseStopBeforeParam(params map[string]string) composeStepOption {
	if params == nil {
		return composeStepOption{enabled: true, services: []string{"api", "rpc"}}
	}
	v := strings.TrimSpace(strings.ToLower(params["stop_before"]))
	switch v {
	case "0", "false", "no", "off":
		return composeStepOption{enabled: false}
	case "", "1", "true", "yes", "all":
		return composeStepOption{enabled: true, services: []string{"api", "rpc"}}
	default:
		return composeStepOption{enabled: true, services: splitCSV(v)}
	}
}

func parseRestartParam(params map[string]string) composeStepOption {
	if params == nil {
		return composeStepOption{enabled: true, services: []string{"api", "rpc"}}
	}
	v := strings.TrimSpace(strings.ToLower(params["restart"]))
	switch v {
	case "", "1", "true", "yes", "all":
		return composeStepOption{enabled: true, services: []string{"api", "rpc"}}
	case "0", "false", "no", "off":
		return composeStepOption{enabled: false}
	default:
		return composeStepOption{enabled: true, services: splitCSV(v)}
	}
}

func splitCSV(s string) []string {
	var out []string
	for _, part := range strings.Split(s, ",") {
		part = strings.TrimSpace(part)
		if part != "" {
			out = append(out, part)
		}
	}
	return out
}

func uploadOneFile(ctx context.Context, client *sftp.Client, localPath, remotePath string, sink LogSink) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}

	st, err := os.Stat(localPath)
	if err != nil {
		return fmt.Errorf("本机缺少 %s（请先执行 backend_build_linux）: %w", localPath, err)
	}
	if st.IsDir() {
		return fmt.Errorf("%s 是目录，不是二进制文件", localPath)
	}

	if sink != nil {
		sink(fmt.Sprintf("↑ %s (%d bytes) → %s\n", localPath, st.Size(), remotePath))
	}

	remoteDir := remotePath[:strings.LastIndex(remotePath, "/")]
	if err := sftpMkdirAll(client, remoteDir); err != nil {
		return fmt.Errorf("创建远程目录 %s: %w", remoteDir, err)
	}

	src, err := os.Open(localPath)
	if err != nil {
		return err
	}
	defer src.Close()

	label := filepath.Base(remotePath)
	tmpRemote := remotePath + sftpUploadSuffix
	_ = client.Remove(tmpRemote)

	dst, err := client.Create(tmpRemote)
	if err != nil {
		return fmt.Errorf("远程创建 %s: %w（可先停止 api/rpc 容器再上传）", tmpRemote, err)
	}
	if _, err := copyUploadWithProgress(dst, src, sink, label, st.Size()); err != nil {
		_ = dst.Close()
		_ = client.Remove(tmpRemote)
		return fmt.Errorf("上传 %s: %w", remotePath, err)
	}
	if err := dst.Close(); err != nil {
		_ = client.Remove(tmpRemote)
		return err
	}
	if err := client.Chmod(tmpRemote, 0o755); err != nil {
		return fmt.Errorf("chmod %s: %w", tmpRemote, err)
	}
	_ = client.Remove(remotePath)
	if err := client.Rename(tmpRemote, remotePath); err != nil {
		return fmt.Errorf("替换 %s: %w（旧文件可能被占用，可 docker_restart 后再传）", remotePath, err)
	}
	if sink != nil {
		sink(fmt.Sprintf("✓ %s\n", remotePath))
	}
	return nil
}

func sftpMkdirAll(client *sftp.Client, dir string) error {
	dir = strings.ReplaceAll(dir, "\\", "/")
	if dir == "" || dir == "." {
		return nil
	}
	if err := client.MkdirAll(dir); err != nil {
		// 目录已存在时忽略
		if strings.Contains(err.Error(), "exist") {
			return nil
		}
		return err
	}
	return nil
}

func remoteJoin(base string, rel string) string {
	base = strings.TrimSuffix(strings.TrimSpace(base), "/")
	rel = strings.Trim(strings.TrimSpace(rel), "/")
	if base == "" {
		return rel
	}
	if rel == "" {
		return base
	}
	return base + "/" + rel
}
