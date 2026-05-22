package runner

import (
	"context"
	"fmt"
	"strings"

	deploycfg "backend/deploy/config"
)

// IsPipelineJob reports one-click release (build → upload → health check).
func IsPipelineJob(jobType string) bool {
	return strings.TrimSpace(strings.ToLower(jobType)) == "backend_release_pipeline"
}

// RunReleasePipeline runs local build, cloud upload, then container verification.
func (reg *Registry) RunReleasePipeline(
	ctx context.Context,
	cfg *deploycfg.Config,
	req JobRequest,
	sink LogSink,
) (exitCode int, err error) {
	cloudID := "cloud"
	if t := cfg.TargetByID("cloud"); !t.IsSSH() {
		for _, x := range cfg.NormalizeTargets() {
			if x.IsSSH() {
				cloudID = x.ID
				break
			}
		}
	}

	if sink != nil {
		sink("╔══════════════════════════════════════╗\n")
		sink("║  一键发布：编包 → 上传 → 检查容器      ║\n")
		sink("╚══════════════════════════════════════╝\n\n")
	}

	if sink != nil {
		sink("──────── ① 本机编 Linux ────────\n")
	}
	buildSpec := reg.Local.BuildLinuxCommand()
	if sink != nil {
		sink("$ " + DisplayCommand(buildSpec) + "\n")
	}
	code, err := Execute(ctx, buildSpec, sink)
	if err != nil {
		return -1, err
	}
	if code != 0 {
		return code, fmt.Errorf("本机编 Linux 失败 exit=%d", code)
	}

	if sink != nil {
		sink("\n──────── ② 上传 VPS ────────\n")
	}
	uploadReq := JobRequest{Type: "backend_upload_binaries", Params: req.Params}
	code, err = reg.RunBackendUpload(ctx, cloudID, cfg, uploadReq, sink)
	if err != nil {
		return -1, err
	}
	if code != 0 {
		return code, fmt.Errorf("上传 VPS 失败 exit=%d", code)
	}

	if sink != nil {
		sink("\n──────── ③ 检查容器（异常时附日志） ────────\n")
	}
	code, err = reg.VerifyCloudContainers(ctx, cloudID, cfg, sink)
	if err != nil {
		return -1, err
	}
	if code != 0 {
		return code, fmt.Errorf("容器检查未通过 exit=%d", code)
	}
	if sink != nil {
		sink("\n【一键发布】全部完成 ✓\n")
	}
	return 0, nil
}
