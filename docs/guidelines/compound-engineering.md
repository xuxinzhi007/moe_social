# Compound Engineering（CE）— 命令与用法

> **插件**：Cursor 市场 `compound-engineering`（本仓库 [`.cursor/settings.json`](../../.cursor/settings.json) 已 `enabled: true`）  
> **Agent 规则**：[`.cursor/rules/compound-engineering.mdc`](../../.cursor/rules/compound-engineering.mdc)（按需加载，AI 自决是否采用）  
> **官方**：[EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin)

## 理念（与本仓库对齐）

**Plan → Work → Review → Compound → Repeat** — 每轮工作应让下一轮更容易。

| CE 步骤 | 本仓库等价物 |
|---------|----------------|
| Plan | `docs/dev/*` SSOT · [kratos-migration-status.md](../dev/kratos-migration-status.md) · 契约先冻结 |
| Work | `make check` · 域边界 · [parallel-agent-workflow.md](./parallel-agent-workflow.md) |
| Review | `code_review.md` · `/review` · `code-reviewer-agent` |
| Compound | [sessions/_TEMPLATE.md](./sessions/_TEMPLATE.md) · 稳定事实进 L2 · [.cursor/LESSONS.md](../../.cursor/LESSONS.md) |

CE **不替代** `.cursor/rules/*-ai-spec.mdc` 与 `LESSONS`；负责结构化「大任务怎么开、怎么收」。

---

## 安装与配置

> **重要**：`git pull` **不会**安装 Cursor 插件。仓库里的 `.cursor/settings.json` 只是 `enabled: true` 开关；**插件本体、CLI 工具、`config.local.yaml` 都在本机**，换电脑必须重装。

### 会随 Git 过来 / 不会过来

| 随仓库 | 仅本机 |
|--------|--------|
| `.cursor/settings.json`（启用开关） | Cursor 已下载的 CE 插件文件 |
| `.compound-engineering/config.local.example.yaml` | `.compound-engineering/config.local.yaml` |
| `docs/guidelines/compound-engineering.md` | `gh`、`jq` 等 CE 可选 CLI |

### 新电脑 / 新 clone 推荐顺序

1. **安装插件**（见下「方式 A / B」）
2. **`/ce-setup`** — 环境诊断 + 生成本地 `config.local.yaml`
3. 确认：输入 `/` 能看到 `/ce-setup`、`/ce-plan` 等

### 方式 A：Cursor 插件市场（首选）

**Agent 聊天：**

```text
/add-plugin compound-engineering
```

**或 GUI：**

- `Cmd+Shift+P` → **Cursor: Open Plugin Marketplace**
- 搜索 `compound engineering` → **Install**

也可在 Cursor Settings（`Cmd+Shift+J`）→ **Plugins** 中安装。

### 方式 B：本机手动安装（市场下载失败时）

当 `/add-plugin` 无报错但 `/` 里没有 `ce-*` 时，多为**空缓存目录**（见下文「故障排查」）。可绕过市场，从 GitHub 链到本地：

```bash
# 任选目录 clone（不必在 moe_social 仓库内）
git clone https://github.com/EveryInc/compound-engineering-plugin.git
mkdir -p ~/.cursor/plugins/local
ln -sf "$(pwd)/compound-engineering-plugin/plugins/compound-engineering" \
  ~/.cursor/plugins/local/compound-engineering
```

然后 **完全退出 Cursor（Cmd+Q）** 再打开，或 `Cmd+Shift+P` → **Developer: Reload Window**。输入 `/` 验证 `/ce-setup`。

### 初始化检查（插件装好后再做）

```text
/ce-setup
```

**环境诊断 + 项目引导**，交互式跑一遍。适合：刚装插件、升级插件后、某 skill 报「工具未安装」、新机器 / 新 clone 本仓库。

| 阶段 | 做什么 |
|------|--------|
| **诊断** | 检查 CE 依赖 CLI（`gh`、`jq`、`agent-browser`、`ast-grep` 等）、插件版本、本仓库 CE 配置状态 |
| **修复** | 可选：从模板生成 `.compound-engineering/config.local.yaml`；补 `.gitignore`；多选安装缺失工具 |
| **清理** | 若存在旧版根目录 `compound-engineering.local.md`，会提示删除（已废弃） |

本仓库当前状态：

- ✅ `.compound-engineering/config.local.example.yaml` 已提交
- ✅ `.gitignore` 已含 `.compound-engineering/*.local.yaml`
- ⬜ `config.local.yaml` 需运行 `/ce-setup` 或手动 `cp` 后才有（机器本地，不提交）

可随时重跑 `/ce-setup` 做健康检查。官方说明：[ce-setup.md](https://github.com/EveryInc/compound-engineering-plugin/blob/main/docs/skills/ce-setup.md)

### 本地配置（可选，setup 可代劳）

```bash
cp .compound-engineering/config.local.example.yaml .compound-engineering/config.local.yaml
```

| 配置项 | 用途 |
|--------|------|
| `work_delegate: codex` | 将执行委托给 Codex CLI |
| `work_delegate_consent` / `work_delegate_model` | 委托开关与模型 |
| `pulse_*` | `/ce-product-pulse` 数据源（PostHog、Sentry 等） |
| `plan_output` / `brainstorm_output` | `md` 或 `html` |

`config.local.yaml` 已在 `.gitignore`，勿提交密钥。

---

## 命令速查

在 Cursor Agent 输入 `/` 搜索 `ce-` 前缀。

### 策略与创意（上游）

| 命令 | 用途 | 典型产出 |
|------|------|----------|
| `/ce-strategy` | 产品方向锚点 | `STRATEGY.md` |
| `/ce-ideate` | 大范围创意与排序 | 排名后的 ideation 文档 |
| `/ce-brainstorm` | 交互式澄清需求 | `docs/brainstorms/*-requirements.md` |

### 核心循环

| 命令 | 用途 | 典型产出 |
|------|------|----------|
| `/ce-plan` | 需求 → 实现计划 | `docs/plans/*.md` |
| `/ce-work` | 按计划执行（worktree、任务） | 分支 + PR |
| `/ce-code-review` | 多维度审查 | review findings |
| `/ce-compound` | **沉淀经验**（最重要） | `docs/solutions/*.md` |
| `/ce-debug` | 系统化排障 | 根因 + 修复 |

### 观测与维护

| 命令 | 用途 |
|------|------|
| `/ce-product-pulse` | 时间窗口产品脉冲（用法、错误、转化） |
| `/ce-setup` | **初始化 / 环境健康检查**（首次安装、升级后、排障） |
| `/ce-product-pulse setup` | 配置 `pulse_*` 产品脉冲数据源 |
| `/ce-doc-review` | 文档审查 |

---

## 推荐工作流

### 新功能（跨栈 / ≥5 文件）

```text
/ce-brainstorm "功能简述与约束"
/ce-plan docs/brainstorms/xxx-requirements.md
/ce-work
/ce-code-review
/ce-compound
```

**本仓库注意**：Flutter / backend / moe-admin 契约联动时，先冻结 `api/*/v1/*.proto`，再并行 UI（见 [parallel-agent-workflow.md](./parallel-agent-workflow.md)）。

### 修 Bug（单域、步骤明确）

Agent 通常 **不必** 走全套 CE；直接修 + `make check` / `flutter analyze`。复杂根因可用：

```text
/ce-debug "复现步骤与现象"
/ce-compound
```

### 文档 / 瘦身 / 索引对齐

```text
/ce-brainstorm "文档合并范围与 SSOT"
/ce-plan docs/brainstorms/xxx-requirements.md
```

执行可由当前 Agent 完成，收尾用 Session 摘要（不必强行 `/ce-work`）。

### 合并前审查

```text
/ce-code-review
```

或仓库内 `/review` + `code_review.md`（二选一，避免重复审两遍）。

---

## 产出目录约定（CE × Moe Social）

| CE 默认路径 | 本仓库建议 |
|-------------|------------|
| `docs/brainstorms/` | 可保留；大方案稳定后合并进 `docs/dev/` 或 `docs/product/` |
| `docs/plans/` | 冲刺计划；结束归档到 `docs/guidelines/sessions/` |
| `docs/solutions/` | 可检索解法；与 Session 不重复时保留 |
| `STRATEGY.md` | 产品级；与 [product/项目开发总览](../product/项目开发总览与当前优先级-2026-05-18.md) 对齐 |
| `docs/pulse-reports/` | 运营脉冲；与产品指标文档互链 |

**Compound 收尾**：优先 [sessions/_TEMPLATE.md](./sessions/_TEMPLATE.md)；重复踩坑 **提议** 写入 `.cursor/LESSONS.md`（人确认后再改）。

---

## Agent 自决：何时用 / 何时不用

### 建议采用 CE 流程

- 需求模糊、多方案权衡、≥5 文件或 ≥2 目录
- 跨 `lib/` + `backend/` + `moe-admin/` 联动
- 合并前需要系统化 review
- 本轮有可复用架构/流程教训

### 不必走 CE

- 单文件 bug、纯问答、用户已给完整步骤
- 仅改文档链接/错别字
- 紧急热修（先修后补 compound）

### Agent 无 `/ce-*` 时

在 Cursor Agent 内无法代用户输入斜杠命令时，**按同一四步执行**，并在回复中说明「已按 CE 流程」；可建议用户在**新会话**中运行 `/ce-plan` 等以复用插件子 agent。

---

## 与现有工具对照

| 场景 | CE | 本仓库原生 |
|------|-----|------------|
| 大任务拆分 | `/ce-work` | `Task` 子代理 + [parallel-agent-workflow.mdc](../../.cursor/rules/parallel-agent-workflow.mdc) |
| 代码审查 | `/ce-code-review` | `/review` · `code-reviewer-agent` |
| 会话沉淀 | `/ce-compound` | Session 摘要 · `docs/guidelines/sessions/` |
| 重复踩坑 | compound 文档 | `.cursor/LESSONS.md` |
| 后端验收 | — | `cd backend && make check` |
| Flutter 验收 | — | `flutter analyze` · `flutter test` |

---

## 故障排查

### `/add-plugin` 无反应或装不上

**常见原因**：Cursor 认为已安装，但缓存目录是**空的**（`/add-plugin` 不会重新下载）。

本机可自检（macOS）：

```bash
ls -la ~/.cursor/plugins/cache/cursor-public/compound-engineering
```

若只有 `.` / `..`、无子文件 → 属于「空壳安装」。

**推荐：清缓存后重装（不必删仓库里的 `.cursor/settings.json`）**

1. **完全退出 Cursor**（`Cmd+Q`，不要只 Reload）
2. 删除空壳与缓存（可整目录清 cache）：

```bash
rm -rf ~/.cursor/plugins/cache/cursor-public/compound-engineering
# 仍失败时可扩大清理：
rm -rf ~/.cursor/plugins/cache/*
```

3. 重新打开 Cursor，确认已登录
4. **Settings → Network → Run Diagnostics**（需能访问 `*.cursorapi.com`、`github.com`）
5. 再装一次：**Plugin Marketplace → Install**，或 `/add-plugin compound-engineering`
6. 验证：输入 `/` → 应有 `/ce-setup`；再跑 `/ce-setup`

**仍失败**：改用上文 **方式 B 手动 symlink**；或检查 VPN/公司代理是否拦截 `marketplace.cursorapi.com`。

### 为什么 `git push` 正常，但插件装不上？

本仓库 `origin` 是 **SSH**（`git@github.com:...`），不走 `https://github.com`。  
而失效的 `ghproxy` 规则只重写 **HTTPS** 地址，所以 **push/pull（SSH）不受影响**，但 Cursor 市场、HTTPS `git clone` 会失败。

自检：

```bash
git remote -v
git config --global --get-regexp 'url\..*insteadof|proxy'
```

### Git 推荐配置（不依赖本机代理常开）

**不要用** 失效的 `ghproxy.com` `insteadOf`，也**不建议**写死 `http.proxy=127.0.0.1:xxxx`（代理没开时所有 HTTPS git 都会挂）。

**推荐**：让 GitHub 的 HTTPS 自动走 SSH（你已能 `git push` 即可）：

```bash
# 移除失效 ghproxy（若存在）
git config --global --unset url.https://ghproxy.com/https://github.com.insteadof

# 移除全局本机代理（若曾设置）
git config --global --unset http.proxy
git config --global --unset https.proxy

# HTTPS → SSH 自动转换（代理关着也能用）
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

验证：

```bash
git ls-remote --heads https://github.com/EveryInc/compound-engineering-plugin.git | head -1
```

### 本机代理「有时开、有时关」时

| 场景 | 做法 |
|------|------|
| **Git 操作** | 用上文 HTTPS→SSH，**无需**本机代理 |
| **代理开着、临时要 HTTPS** | 单次加代理：`git -c http.proxy=http://127.0.0.1:7897 clone https://...` |
| **Cursor 插件市场** | 走 Cursor 自己的网络；代理关着可能装不上 → 用下方方式 B 手动安装 |
| **公共 ghproxy 等「远程代理」** | **不推荐**：易失效、有安全风险，且与 SSH 行为不一致 |

没有「永远可用的免费 GitHub 代理地址」可写进全局配置；可靠做法是 **SSH + 需要时手动开本机代理**。

### 市场仍失败时：手动安装（方式 B）

```bash
git clone --depth 1 git@github.com:EveryInc/compound-engineering-plugin.git ~/tools/compound-engineering-plugin
mkdir -p ~/.cursor/plugins/local
ln -sf ~/tools/compound-engineering-plugin/plugins/compound-engineering \
  ~/.cursor/plugins/local/compound-engineering
```

`Cmd+Q` 重开 Cursor 后输入 `/` 验证 `/ce-setup`。

| 现象 | 处理 |
|------|------|
| 输入 `/` 无 `ce-` 命令 | 空缓存重装，或方式 B 手动安装 |
| `/add-plugin` 有 `ConnectError` | Network 诊断；关 VPN 后 `Cmd+Q` 重开 Cursor |
| `settings.json` 已 `enabled: true` 仍无命令 | **正常**：开关 ≠ 已下载；必须完成市场或手动安装 |
| 委托 Codex 失败 | 配置 `.compound-engineering/config.local.yaml` 的 `work_delegate_*` |
| 与仓库规范冲突 | **以** `*-ai-spec.mdc` **与** SSOT **为准** |

### 要不要删 `.cursor/settings.json` 里的插件项？

**一般不用删。** 该项只控制「本项目是否启用 CE」；删掉**不会**触发重新下载。  
重装流程是：**清 `~/.cursor/plugins/cache` → 市场 Install / `/add-plugin`（或方式 B）** → 保持 `"enabled": true`。

### 开发者工具辅助定位

`Cmd+Option+I` 打开 Console，安装时若见 `ConnectError`、`PluginsProviderService` 超时，优先查网络与登录状态。

---

最后更新：**2026-05-29**
