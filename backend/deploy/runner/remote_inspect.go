package runner

import (
	"context"
	"fmt"
	"strings"

	deploycfg "backend/deploy/config"
)

// RemoteCheckResult is a structured VPS path / compose inspection.
type RemoteCheckResult struct {
	OK                 bool     `json:"ok"`
	Message            string   `json:"message"`
	BackendDir         string   `json:"backend_dir"`
	ComposeFile        string   `json:"compose_file"`
	BackendDirExists   bool     `json:"backend_dir_exists"`
	ComposeFileExists  bool     `json:"compose_file_exists"`
	SuggestedBackend   string   `json:"suggested_backend_dir,omitempty"`
	ComposeCandidates  []string `json:"compose_candidates,omitempty"`
	RawOutput          string   `json:"raw_output,omitempty"`
}

// RemoteInspectScript builds a shell script to verify paths on the VPS.
func RemoteInspectScript(backendDir, composeFile string) string {
	be := shellQuote(strings.TrimSpace(backendDir))
	cfName := strings.TrimSpace(composeFile)
	if cfName == "" {
		cfName = "docker-compose.binary.yml"
	}
	cf := shellQuote(cfName)
	return fmt.Sprintf(`echo MOE_CHECK_BEGIN
echo backend_dir=%s
if [ -d %s ]; then echo backend_dir_exists=yes; else echo backend_dir_exists=no; fi
if [ -f %s/%s ]; then echo compose_exists=yes; else echo compose_exists=no; fi
echo MOE_FIND_COMPOSE_BEGIN
find /root /home /opt -maxdepth 6 -name 'docker-compose.binary.yml' 2>/dev/null | head -15
echo MOE_FIND_COMPOSE_END
echo MOE_LS_ROOT
ls -la /root 2>/dev/null | head -25
echo MOE_LS_GOWORK
ls -la /root/gowork 2>/dev/null | head -25
echo MOE_CHECK_END`, be, be, be, cf)
}

// ParseRemoteInspectOutput parses probe script output.
func ParseRemoteInspectOutput(out, configuredBackend string) RemoteCheckResult {
	res := RemoteCheckResult{
		BackendDir:  configuredBackend,
		ComposeFile: "docker-compose.binary.yml",
		RawOutput:   strings.TrimSpace(out),
	}
	inFind := false
	var candidates []string
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		switch {
		case line == "backend_dir_exists=yes":
			res.BackendDirExists = true
		case line == "compose_exists=yes":
			res.ComposeFileExists = true
		case strings.HasPrefix(line, "backend_dir="):
			if v := strings.TrimPrefix(line, "backend_dir="); v != "" {
				res.BackendDir = v
			}
		case line == "MOE_FIND_COMPOSE_BEGIN":
			inFind = true
		case line == "MOE_FIND_COMPOSE_END":
			inFind = false
		case inFind && line != "" && strings.Contains(line, "docker-compose"):
			candidates = append(candidates, line)
		}
	}
	res.ComposeCandidates = candidates
	if len(candidates) > 0 && !res.BackendDirExists {
		res.SuggestedBackend = strings.TrimSuffix(candidates[0], "/"+res.ComposeFile)
		if res.SuggestedBackend == candidates[0] {
			res.SuggestedBackend = strings.TrimSuffix(candidates[0], "\\"+res.ComposeFile)
		}
	}
	res.OK = res.BackendDirExists && res.ComposeFileExists
	if res.OK {
		res.Message = "远程路径与 compose 文件就绪，可执行 Docker 任务"
		return res
	}
	if !res.BackendDirExists {
		msg := fmt.Sprintf("backend_dir 不存在: %s", res.BackendDir)
		if res.SuggestedBackend != "" {
			msg += fmt.Sprintf("；建议在 config.yaml 改为: %s", res.SuggestedBackend)
		} else if len(candidates) > 0 {
			msg += fmt.Sprintf("；发现 compose: %s", strings.Join(candidates, ", "))
		}
		res.Message = msg
		return res
	}
	res.Message = fmt.Sprintf("compose 文件不存在: %s/%s", res.BackendDir, res.ComposeFile)
	return res
}

// RunRemoteCheck executes path inspection on an SSH target.
func RunRemoteCheck(ctx context.Context, cfg *deploycfg.Config, targetID string) (RemoteCheckResult, error) {
	t := cfg.TargetByID(targetID)
	if !t.IsSSH() {
		return RemoteCheckResult{Message: "仅 SSH 云平台目标可巡检"}, fmt.Errorf("not ssh target")
	}
	rp := NewRemotePlatform(t)
	cf := t.ComposeFile
	if cf == "" {
		cf = cfg.ComposeFile
	}
	script := RemoteInspectScript(t.BackendDir, cf)
	spec := CommandSpec{
		Label:     "remote path check",
		Shell:     true,
		ShellLine: script,
		SSH:       rp.sshConfig(),
	}
	out, code, err := RunCapture(ctx, spec)
	res := ParseRemoteInspectOutput(out, t.BackendDir)
	res.ComposeFile = cf
	if err != nil {
		res.Message = err.Error()
		return res, err
	}
	if code != 0 && res.Message == "" {
		res.Message = fmt.Sprintf("巡检脚本 exit=%d", code)
	}
	return res, nil
}
