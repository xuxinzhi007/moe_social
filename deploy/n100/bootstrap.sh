#!/usr/bin/env bash
# N100 一次性：运行时目录、user systemd、ops 写权限。在小主机上执行：
#   bash deploy/n100/bootstrap.sh
set -euo pipefail

RUNTIME="${HOME}/moe-runtime"
OPS_DIR="/var/www/html/ops"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "repo=${REPO_ROOT}"
echo "runtime=${RUNTIME}"

mkdir -p "${RUNTIME}/bin" "${RUNTIME}/config" "${RUNTIME}/data/images"
mkdir -p "${HOME}/.config/systemd/user"

cp -f "${REPO_ROOT}/deploy/n100/moe-social.service" \
  "${HOME}/.config/systemd/user/moe-social.service"

if [[ ! -f "${RUNTIME}/config/config.yaml" ]]; then
  if [[ -f "${REPO_ROOT}/backend/config/config.yaml" ]]; then
    cp "${REPO_ROOT}/backend/config/config.yaml" "${RUNTIME}/config/config.yaml"
    echo "copied backend/config/config.yaml -> ${RUNTIME}/config/config.yaml"
    echo "edit DB host / secrets on this machine; pipeline will not overwrite it"
  else
    echo "WARN: no config.yaml yet; copy one to ${RUNTIME}/config/config.yaml before start"
  fi
fi

if [[ -d "${OPS_DIR}" ]]; then
  if sudo -n chown -R "${USER}:www-data" "${OPS_DIR}" 2>/dev/null; then
    sudo -n chmod -R u+rwX,g+rwX "${OPS_DIR}" || true
    echo "ops dir writable: ${OPS_DIR}"
  else
    echo "ops dir exists; if admin deploy fails, run:"
    echo "  sudo chown -R ${USER}:www-data ${OPS_DIR}"
  fi
else
  echo "WARN: ${OPS_DIR} missing (nginx /ops not deployed yet)"
fi

if command -v loginctl >/dev/null 2>&1; then
  sudo loginctl enable-linger "${USER}" || true
fi

systemctl --user daemon-reload
systemctl --user enable moe-social.service || true

echo
echo "Next: install GitHub self-hosted runner with label n100"
echo "  https://github.com/xuxinzhi007/moe_social/settings/actions/runners/new"
echo "Then: Actions → N100 deploy → Run workflow"
echo
echo "Start API after binary exists:"
echo "  systemctl --user start moe-social"
echo "  systemctl --user status moe-social --no-pager"
