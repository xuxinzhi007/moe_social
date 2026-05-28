# goctl 生成与合并 Logic 说明

> **更新：2026-05-27**

## 核心原则（本仓库）

**不要把业务从合并文件搬到 goctl 单文件里。**  
正确做法相反：

| goctl 生成 | 本仓库做法 |
|------------|------------|
| 每接口一个 `admincreatetopictaglogic.go` 空壳 | **删掉空壳**，实现留在 **`admin_insights_logic.go`** |
| `// todo: add your logic` | 在**合并文件**里写完整方法 |

`make gen-api` 结束后会自动跑 `prune-api-logic-shells.sh`（已修复路径），删除与合并文件重复的 todo 壳。

## 合并文件 SSOT（示例）

| 域 | 合并实现文件 | goctl 会误生成的壳 |
|----|--------------|-------------------|
| Admin 洞察/标签 | `api/internal/logic/admin/admin_insights_logic.go` | `admin*topictag*logic.go`、`admin*aichat*logic.go` 等 |
| Admin Moe Flow | `api/internal/logic/admin/admin_moe_flow_logic.go` | `admin*moebotflow*logic.go` |
| User 好友 | `api/internal/logic/user/friendlogic.go` | `sendfriendrequestlogic.go` 等（handler 用 `NewFriendLogic`） |
| LLM 配置 | handler 直调 `LLMApp` | `configlogic.go` |

新增接口若与现有合并文件同域，**扩展现有 `*_logic.go`**，不要新建 goctl 单文件再迁代码。

## 命令

```bash
cd backend
make gen-api          # goctl → 自动 prune → post-gen-check → gen-http-routes
make check
```

若 prune 漏删，登记 `scripts/goctl-orphan-stubs.txt`。

## P3 logic 退役（2026-05-28）

- compat 层 **不得** import `api/internal/logic`（已达成）
- 删除 logic 前：`make audit-logic-orphans`（无 handler 引用才可删）
- handler 已直调 biz 的域（image、remote WS）logic 已删；其余 ~252 类型待 handler 改线后删

## 冲突症状

- `redeclared in this block`：同一 `AdminCreateTopicTagLogic` 在两个 `.go` 里
- `not enough return values`：空壳 `return` 无返回值

**处理**：保留 `admin_insights_logic.go` 中的实现，删除 `admincreatetopictaglogic.go` 等壳（或再跑 `bash scripts/gen/prune-api-logic-shells.sh`）。

## 与 `make gen` 的关系

- **`make gen`**：不跑 goctl api，**不会**产生这些壳
- **`make gen-api`**：才会 goctl 生成；**必须**带 prune
