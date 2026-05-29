package runner

import (
	"context"
	"fmt"

	deploycfg "backend/deploy/config"
)

var deployContainerNames = []string{"moe-social"}

// VerifyCloudContainers checks moe-social after deploy; dumps logs when not healthy.
func (reg *Registry) VerifyCloudContainers(
	ctx context.Context,
	targetID string,
	cfg *deploycfg.Config,
	sink LogSink,
) (exitCode int, err error) {
	targetID = SuggestedTarget("docker_ps", targetID)
	t := cfg.TargetByID(targetID)
	if !t.IsSSH() {
		return 1, fmt.Errorf("容器检查需要 cloud SSH 目标")
	}
	rp, ok := reg.Remote[t.ID]
	if !ok {
		return 1, fmt.Errorf("未配置远程目标 %q", t.ID)
	}
	cf := rp.Target.ComposeFile
	if cf == "" {
		cf = "docker-compose.binary.yml"
	}
	be := shellQuote(rp.Target.BackendDir)
	cfQ := shellQuote(cf)

	script := fmt.Sprintf(`set -e
cd %s
echo "=== docker compose ps ==="
docker compose -f %s ps 2>/dev/null || docker-compose -f %s ps
fail=0
for name in moe-social; do
  if ! docker inspect "$name" >/dev/null 2>&1; then
    echo "=== $name: 容器不存在 ==="
    fail=1
    continue
  fi
  st=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo unknown)
  restarting=$(docker inspect -f '{{.State.Restarting}}' "$name" 2>/dev/null || echo false)
  exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$name" 2>/dev/null || echo 0)
  echo "=== $name: status=$st restarting=$restarting exit=$exit_code ==="
  case "$st" in
    running)
      if [ "$restarting" = "true" ]; then
        echo "=== $name 处于重启中，拉取日志 ==="
        fail=1
        docker logs --tail 150 "$name" 2>&1 || true
      fi
      ;;
    *)
      echo "=== $name 未正常运行，拉取日志 ==="
      fail=1
      docker logs --tail 150 "$name" 2>&1 || true
      ;;
  esac
done
exit $fail
`, be, cfQ, cfQ)

	if sink != nil {
		sink("$ 容器健康检查\n")
	}
	code, runErr := runSSHNative(ctx, *rp.sshConfig(), script, sink)
	if runErr != nil {
		return -1, runErr
	}
	if code != 0 && sink != nil {
		sink("【检查】moe-social 存在异常，请查看上方日志\n")
	}
	return code, nil
}
