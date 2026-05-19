# 安全与稳定性修复 backlog

本文档整理代码审查中**尚未在本轮完成**或**需后续迭代**的项。已完成项见文末「本轮已处理」。

---

## P0 — 上线前必须完成

| 项 | 说明 | 建议动作 |
|----|------|----------|
| JWT 密钥轮换 | 若仓库/服务器曾泄露旧密钥，需更换 `auth.access_secret` 并重启 API+RPC | 生成新随机串（≥32 字符），更新 `backend/config/config.yaml` 或 `MOE_AUTH_ACCESS_SECRET` |
| Android 签名密码 | `README` 已移除明文；`build.gradle.kts` 仍有 `moe123456` 回退 | 删除 Gradle 默认密码，强制环境变量；密码存 1Password/Vault |
| 生产环境变量 | 公网部署勿把 `config.yaml` 里的密钥提交 Git | 使用 `MOE_AUTH_ACCESS_SECRET` + 服务器侧 secret 文件 |

---

## P1 — 建议 1～2 周内

| 项 | 位置 | 风险 | 建议 |
|----|------|------|------|
| AI `PayloadJson` 大小限制 | `rpc/.../ai_resources_logic.go` `upsert` | 超大 JSON 拖垮 DB/内存 | 单条 ≤ 64KB，agents/providers 条数上限 |
| AI 字段白名单 | 同上 | 任意键写入 | 仅允许 `id/name/model_name/...` 等业务字段 |
| HTTP 重试 `time.Sleep` | `api/.../llm/*logic.go` | 高并发时占用 goroutine | 抽 `utils/retry` 或 resty，支持 context 取消 |
| WebSocket `json.Marshal` 忽略错误 | `api/internal/websocket/router.go` 等 | 静默失败 | 逐项补错误日志/关闭连接 |

---

## P2 — 可随模块改动

| 项 | 位置 | 说明 |
|----|------|------|
| `io.ReadAll` 忽略错误 | 多个 LLM handler | 非 200 时读 body 失败无日志 |
| `utils/db.go` 绝对路径 | `InitConfig` | `/Users/admin/...` 应删除，仅保留相对 `config` 路径 |
| pprof 监控 | `rpc/super.go` | 仅 `127.0.0.1:6060`，生产勿暴露 |
| 飞书 webhook 在 config.yaml | `backend/config/config.yaml` | 若进 Git 需迁到环境变量 |

---

## 本轮已处理（2026-05）

| 项 | 处理方式 |
|----|----------|
| JWT 多处硬编码 | 统一 `backend/config/config.yaml` → `auth.access_secret`；`utils.ConfigureJWT`；API/RPC 启动时加载 |
| JSON `Marshal` 忽略错误 | `ai_resource_helpers`、`ai_resources_logic`、`resource_logic`、`userconfiglogic`、私信/帖子图片序列化 |
| 记忆缓存无上限 | `chatlogic.go`：TTL 保留 + 最多 512 用户条目 + 过期/最旧淘汰 |
| 后台记忆提取无界 | `backgroundMemoryExtractContext` 上限 60s |
| README 签名明文 | 迁至 `docs/dev/android-release-signing.md`，README 仅保留链接 |
| 性能监控页 | `monitor.html` + `rpc/internal/debug` JSON 接口 |

---

## 配置速查

### JWT（唯一配置源）

```yaml
# backend/config/config.yaml
auth:
  access_secret: "<随机长字符串>"
  access_expire_seconds: 432000
```

环境变量覆盖：`MOE_AUTH_ACCESS_SECRET`

### 启动检查

```bash
cd backend/rpc && go run super.go    # 应打印 monitor 地址
cd backend/api && go run super.go -f etc/super.yaml
```

JWT 未配置时 API/RPC 启动会直接 `fatal` 并提示修改 `config.yaml`。

---

## 参考

- 审查对照：`docs/dev/security-and-stability-backlog.md`（本文件）
- Android 签名：`docs/dev/android-release-signing.md`
- RPC 监控：`monitor.html` + `http://127.0.0.1:6060/debug/live`
