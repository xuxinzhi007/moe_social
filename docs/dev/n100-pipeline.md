# N100 自托管流水线

在家用小主机（`n100-server`，局域网 `192.168.124.77`）上用 **GitHub self-hosted runner** 编译并发布预发环境。云主机 `47.106.175.49` 仍是 App 生产入口，本流水线不替换它。

## 背景

小主机没有公网入站，GitHub 云端 Runner 无法 SSH 进来。Runner 装在 N100 上、主动连 GitHub，即可在内网完成构建和重启。

## 方案

```text
GitHub（手动 workflow_dispatch）
  → N100 上的 runner（label: n100）
       编 backend → ~/moe-runtime/bin/moe-social → systemd --user 重启
       编 moe-admin → /var/www/html/ops（现有 Nginx）
```

- 不在 N100 打 Flutter APK（继续用 `.github/workflows/flutter-release.yml`）。
- 不覆盖 `~/moe-runtime/config/config.yaml`（密钥只留机器上）。
- 当前仓库生产入口实际是 `backend/cmd/moe-social-stack`（`-agent=false`），二进制仍命名为 `moe-social`。

## 影响范围

- 新增：`.github/workflows/n100-deploy.yml`、`deploy/n100/`、本文。
- 不改云 Docker、不改 App `api_base_url`。

## 一次性安装（在 N100 上）

```bash
# 1. 克隆仓库（若还没有）
git clone git@github.com:xuxinzhi007/moe_social.git ~/moe_social
cd ~/moe_social
bash deploy/n100/bootstrap.sh
```

然后按脚本打印的说明，到 GitHub → Settings → Actions → Runners → New self-hosted runner，标签填 `n100`。

GitHub：https://github.com/xuxinzhi007/moe_social/settings/actions/runners/new

装好后 Actions 里手动跑 **N100 deploy**。

## 迁移步骤

1. 跑 `bootstrap.sh`，确认 `systemctl --user status moe-social` 能起来（配置和库先抄一份能连的 `config.yaml`）。
2. 注册 runner，在 Actions 里 `workflow_dispatch`，先只选 `backend`。
3. 本机访问 `http://192.168.124.77:8888/migration` 或健康接口确认。
4. 再跑一次选 `admin`，打开 `http://192.168.124.77/ops/`。
5. 公网仍走现有 Quick tunnel → Nginx `:80`；等后端在 N100 稳定后再改 Nginx `/api` 指本机 8888。

## 回滚

- 停发布：GitHub 里 Disable runner 或停用 workflow。
- 停服务：`systemctl --user stop moe-social`
- 管理台：用本机 `cd moe-admin && npm run deploy:lan` 再覆盖一次 `/var/www/html/ops`。
- 生产 App：继续打云主机，不受本流水线影响。
