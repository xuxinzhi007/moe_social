package runner

import (
	"context"
	"fmt"
	"strings"

	deploycfg "backend/deploy/config"
)

// RemoteCheckResult is a structured VPS path / compose / API→RPC config inspection.
type RemoteCheckResult struct {
	OK                   bool     `json:"ok"`
	Message              string   `json:"message"`
	BackendDir           string   `json:"backend_dir"`
	ComposeFile          string   `json:"compose_file"`
	BackendDirExists     bool     `json:"backend_dir_exists"`
	ComposeFileExists    bool     `json:"compose_file_exists"`
	ComposeRpcEnvSet     bool     `json:"compose_rpc_env_set"`
	ComposeRpcEnvOK      bool     `json:"compose_rpc_env_ok"`
	ConfigRpcEndpointsOK bool     `json:"config_rpc_endpoints_ok"`
	ApiContainerRpcEnvOK string   `json:"api_container_rpc_env_ok"` // yes | no | na
	LegacySuperDocker    bool     `json:"legacy_super_docker_yaml"`
	RpcConfigOK          bool     `json:"rpc_config_ok"`
	SuggestedBackend     string   `json:"suggested_backend_dir,omitempty"`
	ComposeCandidates    []string `json:"compose_candidates,omitempty"`
	RawOutput            string   `json:"raw_output,omitempty"`
}

// RemoteInspectScript builds a shell script to verify paths on the VPS.
func RemoteInspectScript(backendDir, composeFile string) string {
	be := shellQuote(strings.TrimSpace(backendDir))
	cfName := strings.TrimSpace(composeFile)
	if cfName == "" {
		cfName = "docker-compose.binary.yml"
	}
	cf := shellQuote(cfName)
	cfg := shellQuote(strings.TrimSpace(backendDir) + "/config/config.yaml")
	return fmt.Sprintf(`echo MOE_CHECK_BEGIN
echo backend_dir=%s
if [ -d %s ]; then echo backend_dir_exists=yes; else echo backend_dir_exists=no; fi
if [ -f %s/%s ]; then echo compose_exists=yes; else echo compose_exists=no; fi
if grep -q 'MOE_SUPER_RPC_ENDPOINT' %s/%s 2>/dev/null; then echo compose_rpc_env_set=yes; else echo compose_rpc_env_set=no; fi
if grep -E 'MOE_SUPER_RPC_ENDPOINT[=:].*rpc:8080' %s/%s 2>/dev/null; then echo compose_rpc_env_ok=yes; else echo compose_rpc_env_ok=no; fi
if [ -f %s ] && grep -A3 'super_rpc_endpoints' %s 2>/dev/null | grep -q 'rpc:8080'; then echo config_rpc_ok=yes; else echo config_rpc_ok=no; fi
if [ -f %s/api/etc/super-docker.yaml ]; then echo legacy_super_docker=yes; fi
if docker inspect moe-social-api >/dev/null 2>&1; then
  if docker inspect moe-social-api --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -q 'MOE_SUPER_RPC_ENDPOINT=rpc:8080'; then
    echo api_env_rpc_ok=yes
  else
    echo api_env_rpc_ok=no
  fi
else
  echo api_env_rpc_ok=na
fi
echo MOE_FIND_COMPOSE_BEGIN
find /root /home /opt -maxdepth 6 -name 'docker-compose.binary.yml' 2>/dev/null | head -15
echo MOE_FIND_COMPOSE_END
echo MOE_LS_ROOT
ls -la /root 2>/dev/null | head -25
echo MOE_LS_GOWORK
ls -la /root/gowork 2>/dev/null | head -25
echo MOE_CHECK_END`, be, be, be, cf, be, cf, be, cf, cfg, cfg, be)
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
		case line == "compose_rpc_env_set=yes":
			res.ComposeRpcEnvSet = true
		case line == "compose_rpc_env_ok=yes":
			res.ComposeRpcEnvOK = true
		case line == "config_rpc_ok=yes":
			res.ConfigRpcEndpointsOK = true
		case line == "legacy_super_docker=yes":
			res.LegacySuperDocker = true
		case strings.HasPrefix(line, "api_env_rpc_ok="):
			res.ApiContainerRpcEnvOK = strings.TrimPrefix(line, "api_env_rpc_ok=")
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
	res.RpcConfigOK = res.ComposeRpcEnvOK || res.ConfigRpcEndpointsOK
	if res.ApiContainerRpcEnvOK == "no" {
		res.RpcConfigOK = false
	}
	res.OK = res.BackendDirExists && res.ComposeFileExists && res.RpcConfigOK
	if res.OK {
		res.Message = "远程路径、compose 与 API→RPC（MOE_SUPER_RPC_ENDPOINT=rpc:8080）就绪"
		if res.LegacySuperDocker {
			res.Message += "；可删除过期的 api/etc/super-docker.yaml"
		}
		return res
	}
	if res.BackendDirExists && res.ComposeFileExists && !res.RpcConfigOK {
		var hints []string
		if !res.ComposeRpcEnvOK && !res.ConfigRpcEndpointsOK {
			hints = append(hints, "compose 需 environment.MOE_SUPER_RPC_ENDPOINT=rpc:8080，或在 config/config.yaml 配置 api.super_rpc_endpoints")
		}
		if res.ApiContainerRpcEnvOK == "no" {
			hints = append(hints, "运行中 API 容器未注入 MOE_SUPER_RPC_ENDPOINT，执行 docker compose restart api")
		}
		if res.LegacySuperDocker {
			hints = append(hints, "仍存在旧版 super-docker.yaml，请 git pull 后删除并改用环境变量")
		}
		res.Message = "路径就绪，但 API→RPC 配置异常：" + strings.Join(hints, "；")
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
