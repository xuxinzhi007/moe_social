# 安全与稳定性修复 backlog

本文档整理代码审查中**尚未在本轮完成**或**需后续迭代**的项。已完成项见文末「本轮已处理」。

---

## P0 — 上线前必须完成

| 项 | 说明 | 建议动作 |
|----|------|----------|
| JWT 密钥轮换 | 若仓库/服务器曾泄露旧密钥，需更换 `auth.access_secret` 并重启 `moe-social`（单进程） | 生成新随机串（≥32 字符），更新 `backend/config/config.yaml` 或 `MOE_AUTH_ACCESS_SECRET` |
| Android 签名密码 | `README` 已移除明文；`build.gradle.kts` 仍有 `moe123456` 回退 | 删除 Gradle 默认密码，强制环境变量；密码存 1Password/Vault |
| 生产环境变量 | 公网部署勿把 `config.yaml` 里的密钥提交 Git | 使用 `MOE_AUTH_ACCESS_SECRET` + 服务器侧 secret 文件 |

---

## P1 — 建议 1～2 周内

> ⚠️ **位置已按 2026-09-08 实际代码复核**。原表引用的 `rpc/…/ai_resources_logic.go`、`api/…/llm/*logic.go`、`api/internal/websocket/router.go` 均已随 go-zero 逻辑层删除。

| 项 | 位置 | 风险 | 建议 |
|----|------|------|------|
| AI `PayloadJson` 大小限制 | `internal/biz/ai/resources.go` | 超大 JSON 拖垮 DB/内存 | 单条 ≤ 64KB，agents/providers 条数上限 |
| AI 字段白名单 | 同上 | 任意键写入 | 仅允许 `id/name/model_name/...` 等业务字段 |
| `io.ReadAll` 忽略错误 | `internal/platform/apicomm/llm_inference_client.go:144,184` · `utils/feishu.go:179,249` · `utils/feishu_oauth.go:108,144` · `utils/feishu_contact.go:63` · `deploy/github/client.go:126,146` · `internal/server/protohttp/game/stream.go:39` | 非 200 时读 body 失败静默无日志，排障时看不到上游返回 | 逐处补 `err` 判断并记日志 |
| HTTP 重试 `time.Sleep` | ⚠️ 新代码未定位到（`apicomm/llm_inference_client.go` 无 retry 分支） | — | 复核：若已随迁移移除则删条；若仍存在请补真实路径 |
| WebSocket `json.Marshal` 忽略错误 | ⚠️ `internal/server/transport/` 下已无 `json.Marshal` 调用 | — | 复核后删条或补真实路径 |

---

## P2 — 可随模块改动

| 项 | 位置 | 说明 |
|----|------|------|
| pprof 无入口 | `cmd/moe-social` | go-zero 时代 `rpc/super.go` 的 `127.0.0.1:6060` monitor 已随文件删除；Kratos 单进程目前**没有**任何 pprof 挂载点，线上无法抓 profile |
| 飞书 webhook 在 config.yaml | `backend/config/config.yaml` | 若进 Git 需迁到环境变量 |

---

## 本轮已处理（2026-05）

| 项 | 处理方式 |
|----|----------|
| JWT 多处硬编码 | 统一 `backend/config/config.yaml` → `auth.access_secret`；`utils/auth_jwt_config.go:26` `ConfigureJWT`；由 `internal/platform/wiring/config_override.go:113` 在启动时加载 |
| JSON `Marshal` 忽略错误 | `ai_resource_helpers`、`ai_resources_logic`、`resource_logic`、`userconfiglogic`、私信/帖子图片序列化 |
| 记忆缓存无上限 | `chatlogic.go`：TTL 保留 + 最多 512 用户条目 + 过期/最旧淘汰 |
| 后台记忆提取无界 | `backgroundMemoryExtractContext` 上限 60s |
| README 签名明文 | 迁至 `docs/dev/android-release-signing.md`，README 仅保留链接 |
| 性能监控页 | `docs/dev/tools/rpc-monitor.html` + `rpc/internal/debug` JSON 接口 ⚠️ **该接口已随 `backend/rpc/` 目录删除，页面当前无数据源** |

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
cd backend
make moe-social                                  # 单进程 :8888，唯一业务入口
curl -s http://127.0.0.1:8888/health
go list -deps ./cmd/moe-social | grep go-zero    # 应无输出
```

> ⚠️ **`auth.access_secret` 缺失不会导致启动失败。** `utils/auth_jwt_config.go:65-72` 的 `jwtSigningKey()` 是在**每次请求时**才返回 `jwt not configured: set auth.access_secret in backend/config/config.yaml`，进程照常起来、`/health` 照常 200。
> 后果：漏配密钥时服务看起来是健康的，只有登录/鉴权接口逐个报错——比启动 fatal 更难发现。建议改为启动期强校验（见 [配置治理审查](./config-hygiene-review-2026-09-08.md) 的统一加载器 `Validate()` 设计）。

---

## 参考

- 审查对照：`docs/dev/security-and-stability-backlog.md`（本文件）
- Android 签名：`docs/dev/android-release-signing.md`
- RPC 监控：`docs/dev/devtools.html`（或 `tools/rpc-monitor.html`）⚠️ **链路当前是断的**——页面经 deploy-agent `:19010` 把 `/debug/*` 代理到 `devports.RpcDebugUpstream()`（`:19011`），但 `make rpc-debug` 已删、无进程监听 19011，`6060` 亦无监听者
- 端口现状：[ports.md](./ports.md)
