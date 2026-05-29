# 部署（单进程 Kratos HTTP）

> **SSOT**：[LAYOUT.md](./LAYOUT.md) · 云平台上传见 [docs/dev/deploy-platform.md](../docs/dev/deploy-platform.md)

## 本地 / 服务器

```bash
cd backend
make build-linux          # 产出 bin/moe-social
make moe-social           # 开发：go run ./cmd/moe-social
```

默认监听 **:8888**，配置 `config/config.yaml`。

## Docker

```bash
cd backend
docker compose up -d --build    # 单服务 moe-social
docker logs moe-social
docker compose down
```

二进制挂载部署（deploy-agent 上传后）：

```bash
docker compose -f docker-compose.binary.yml up -d
```

## 迁移

```bash
make db-migrate
# 或启动时：go run ./cmd/moe-social -migrate
```

历史 api+rpc 双容器文档已过时；归档见 `docs/archive/backend/`。
