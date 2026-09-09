# 配置治理审查（2026-09-08）

> **范围**：`backend/` · `lib/` · `moe-admin/` · `website/` · `deploy/` · `.github/workflows/` · 仓库卫生
> **基线提交**：§0–§12 = `14370f93 feat: 批量更新LLM推理链路与管理台体验`（2026-09-06）；**§16 = `bec11b26 feat(life, arena): 落地M0/M1a活世界营地预览功能`（2026-09-09）**
> **提交状态**：第一批（§13）= `8037287e`、第二批（§14）= `3ebcf62d`、第三批（§15）= `1d5a45ac`，三批均已入库；§15.5 记录的文档一致性收尾与 §12.1 计数修正随第三批一同提交。**第四批（§16）尚未提交，仍在工作区。**
> **性质**：§0–§12 是**只读审查**，所有结论均给出 `文件:行号` 证据，可按附录 A 的命令复核。§13–§16 记录审查之后**已落地的四批改动**（含改动内容与验证结果），性质是变更记录而非审查。
> **有效性**：本文是**绑定基线提交 `14370f93` 的快照**（依 `docs/README.md` 文档维护约定第 3 条）。§11 各批次整改落地后，对应章节即失效，应**直接删除该章节**而非保留 archive stub。所有行号以该基线为准，后续提交可能使其偏移。
> ⚠️ **行号提醒**：四批改动已使 §0–§12 的部分行号失效（尤其 `moewiring/config.go`——该文件从 191 行降到 80 行，原 `:62-190` 区间的引用全部作废；§16 又让 `utils/db.go` 原 `:96-105` 塌缩为 `:96` 一行）。凡被 §13–§16 就地更新过的条目，以更新后的文字为准；未更新的条目按基线行号读。
> **前提说明**：当前仓库内的第三方密钥为**开发期临时凭据，正式版会整体更换**。因此本文的重点不是「密钥泄露应急」，而是**为什么结构上会导致密钥只能写在这里**——结构不改，换完新密钥仍会回到同一状态。

---

## 0. 结论速览

一句话：**项目有 5 个运行环境，但没有环境抽象层**，于是每个环境的值都被硬写进各处被 git 跟踪的文件里，靠人工同步。

| # | 问题 | 严重度 | 关键证据 | 整改批次 |
|---|------|--------|----------|----------|
| 1 | 明文凭据在被跟踪的 `config.yaml` 内 | P0 | `backend/config/config.yaml:11,23,28,51,81,256` | 批次 1 |
| 2 | Android release 签名口令有明文 fallback | P0 | `android/app/build.gradle.kts:27,29` | 批次 1 |
| 3 | 同一 API 地址有 14 处运行时副本 | P1 | 见 §4.1 表 | 批次 3 |
| 4 | 改 yaml 可能不生效（Go 硬编码短路 / 键名写错） | P1 | ⚠️ **部分完成**：Go 硬编码短路那一半已消除（`moewiring/config.go` 那族过渡开关全删，见 §5.3）；键名写错那一半已修（`admin_runtime_config.go` 写蛇形键、`hand_draw_require_moderation` 补 `runtime.` 前缀，见 §5.5 / §14.3）。**剩** `config_override.go:73,97` 的驼峰死别名 | 第 2 步 |
| 5 | 「SSOT」声明与实际真源不符（Agora 段） | P1 | `api/etc/moe.yaml:11` vs `config.yaml` 无该段 | 批次 2 |
| 6 | 端口 SSOT 被越界硬编码 | P2 | ✅ **已消除**：`18888` / `19032` 的硬编码兜底随死函数删除，可执行路径里已无这两个无监听者的端口（见 §4.2、§15.4）。**剩** `6633` / `11434` 未登记 | 批次 5 |
| 7 | 死配置 / 摆设开关制造噪音 | P2 | ⚠️ **部分完成**：零调用方那一类已清空（`api.timeout_ms` 链、15 个 Kratos 过渡开关、`wireKratosNotes` 链，见 §15.2）；`moe.*_api_in_process` 经实测**不是死配置**（40 处活调用点），收敛归第 2 步。原见 §6 表 | 批次 4 收敛清单 → 第 2 步 |
| 8 | 切环境 = 改源码 + 重启 + 提交 | P1 | `lib/utils/config.dart:16`、提交 `96d7a612` | 批次 3 |
| 9 | 服务器配置与仓库配置已永久分叉 | P1 | `backend/scripts/vps-switch-companion-model.sh` | 批次 5 |
| 10 | 4 套部署链互不知情，两条会互删产物 | P1 | `sync-lan.ps1:12,24` vs `n100-deploy.yml:57` | 批次 5 |
| 11 | 调试产物被提交进仓库 | P3 | `moe_ui.xml`、`cover.out`、`duplication-report/` | 批次 6 |
| 12 | 文档描述的配置机制与代码不符 | P2 | 见 §9 表 | 批次 6 |
| 13 | ~~本机拉起后端默认直连生产 MySQL root~~ **已澄清：该库是测试库** | ~~P0~~ → 非问题 | 需求方确认 `47.106.175.49` 为**测试库**，开发机直连属预期便利；凭据入库的问题归入第 1 行 | 不整改 |
| 14 | 文档教的启动命令已整体失效（`make rpc` / `go run super.go`） | P1 → **已完成** | `backend/rpc/` 目录不存在；见 §9.1（2026-09-08 已清理脚本、Go 提示串与 11 份文档） | 批次 6 ✅ |
| **15** | **同一份 `config.yaml` 被 20 处独立打开，回退链各自实现** | **P1** | 见 §12（19 个 `viper.New()` + `utils.InitConfig()` 全局单例，其中 LLM 有两条不一致的链） | 批次 2（已建 `backend/pkg/conf`，待迁调用点） |
| **16** | **已发布的 release APK 连的是开发机局域网 IP，且 CI 全绿、Release 正常发布** | **P0（实际已发生）** | `flutter-release.yml` 不带 `--dart-define` + `config.dart` 的 `isProduction` 硬编码 `false` + `developmentUrl = 192.168.124.36`；见 §14.1 | ✅ 已闭环：`flutter-release.yml` 第 7 步发布前断言 + `config_test.dart` 内网地址断言（**不改 `isProduction` 语义**，因与三条既有规则冲突，方案取舍见 §14.1） |

---

## 1. 最近提交在做什么（8/2 → 9/6）

四个阶段，主线是**大幅探索 + 大幅删除**：

| 时间 | 主题 | 特征 |
|------|------|------|
| 8/2–8/6 | 宠物养成 / 萌农场 / 序列帧工作台 | 大量新增玩法与工具链 |
| 8/15–8/25 | 聊天个性化（主题皮肤、语音消息）、双人直播礼物 PK V1、GPT Responses API | `2b31e3c2` 专门「修 18 个 review 问题并打开 flag」 |
| 8/27–8/28 | **星辉远征 Arena 上线，整套 pet/farm 被删** | `0ff0ab1b` 单提交 −11771 行；`9f080d1d` 加 OSS 媒体存储 |
| 8/28–9/4 | UI 视觉统一、Android 异地联机实验、AI Provider 密钥加密云同步、n100 部署线、文档大清理 | `5877914c` 删 5560 行 docs |
| 9/6 | LLM 推理链路重构（Ollama 原生协议）+ 管理台体验 | `14370f93`，50 文件 |

**从配置治理角度需要注意的三个工作方式信号：**

1. **提交颗粒度过大且混题**。`8b55400b` 一个提交同时改了 GitHub Actions workflow、后端 proto 及生成物、`backend/internal/biz/ai/`、6 个 Flutter 页面、moe-admin 的 nginx 配置与 PowerShell 同步脚本（44 文件 / +4054 行）。`14370f93` 同类（50 文件，含 proto、LLM 客户端、Dart UI、React 管理台、CSS、compose 文件、运维脚本）。这种提交无法回滚单个意图，配置改动也淹没在功能改动里。
2. **环境切换靠提交代码完成**。`96d7a612 更新线上环境` 的全部内容就是 `lib/utils/config.dart` 改一行。
3. **删除功能时残留物未清干净**。`lib/game/pet/` 已清空，但 `assets/pet/config/*.json`（10 个文件）仍被 git 跟踪；`.pet_exists_check.txt` 仍在仓库根目录。

---

## 2. 环境清单：混乱的根源

| 环境 | 后端地址 | LLM 端点 | 配置交付方式 | 谁在维护 |
|------|----------|----------|--------------|----------|
| 本机 `go run` | `127.0.0.1:8888` | `127.0.0.1:6633`（llama-server） | 直接读 `backend/config/config.yaml` | 开发者手改 |
| Docker（Dockerfile 构建） | `:8888` | 同上 | **`COPY config/config.yaml` 烤进镜像** | 镜像重建 |
| Docker（二进制挂载） | `:8888` | 宿主 Ollama | `volumes: ./config` + 4 个 `MOE_LLM_*` env | compose |
| 云 VPS | `47.106.175.49:8888` | — | `/root/gowork/backend/config/config.yaml`，**脚本原地改** | deploy-agent + 手工 |
| n100 小主机 | `192.168.124.77` | `192.168.124.77:11434`（Ollama） | `~/moe-runtime/config/config.yaml`，**bootstrap 拷一次后流水线不再覆盖** | GitHub self-hosted runner |

**关键事实**：这 5 个环境共用**同一份被 git 跟踪的** `backend/config/config.yaml`。任何一台机器的环境值写进去，就变成了其他 4 个环境的错误默认值。`14370f93` 正是这样把 n100 的内网地址提交进了主干：

```yaml
# backend/config/config.yaml:97（14370f93 引入）
llm_inference:
  provider: ollama
  base_url: "http://192.168.124.77:11434"   # ← n100 内网 IP，进了主干
```

同一文件 `:253` 是云 VPS 的 `47.106.175.49`，`:266` 注释里还留着本地 `127.0.0.1` 版本。**三个环境的值同时存在于一个文件，靠注释切换。**

### 2.1 这个结构当前正在造成的实际后果

不是理论风险，是现在这份 `config.yaml` 的直接行为。

**~~后果一：本机跑后端 = 直连生产数据库~~ 已澄清：那是测试库**

```yaml
# backend/config/config.yaml:250-259（当前生效）
#线上ip ：
database:
  host: "47.106.175.49"      # :253 ← 云 VPS 上的**测试库**
  user: "root"
  password: "123456xxZ."     # :256
  dbname: "go_react_demo"

# :263-271（被注释掉的本地版本）
#本地ip :
# database:
#   host: "127.0.0.1"        # :266
#   password: "123456"       # :269
```

需求方已确认：`47.106.175.49` 上的 MySQL 是**测试库**，开发机为了省事直连它是**预期行为**，本地跑 `make db-migrate`（`Makefile:102`）打到它也不构成数据风险。本节原先把它评为 P0 是判断错误，已撤回。

仍然成立、但严重度低得多的两点：

1. **root 口令在 git 里**（`:256`）—— 这与「库是不是测试库」无关，是 §3.1 凭据入库问题的一个实例。测试库被扫到最多丢测试数据，但同一个口令习惯会跟着人走到生产。
2. **两个互斥块靠人工注释切换** —— 换库要编辑被跟踪文件并重启，无法用环境变量或独立文件覆盖。这是结构问题，见本节末尾。

**后果二：本机上传图片会失败，且 URL 指向云 VPS**

```yaml
# backend/config/config.yaml:150-151 的注释写着：
#   图片「云图库」：本机 go run 默认落盘 ./data/images，URL 走本机 :8888
#   Docker/云部署时改回 /app/data/images + 公网域名（见下方注释）
# :152-155 是本机版本，已被注释掉
# :157 的注释写着「生产 / Docker 示例（部署到 VPS 时取消注释并注释掉上方 image 段）」
# :158-162 当前生效的是生产版本：
image:
  local_dir: "/app/data/images"                       # :160 ← macOS 上不存在，已实测 ls -ld /app 无此目录
  public_base_url: "http://47.106.175.49:8888"        # :161 ← 即使写入成功，返回的也是云 VPS 的 URL
```

**注意 `:157` 那句注释本身就是问题所在**：它把「取消注释一段 + 注释掉另一段」当作环境切换的正式手段。`database`（生效 `:252` / 注释 `:265`）、`image`（注释 `:152` / 生效 `:158`）、`app_client.public_api_base_url`（生效 `:138` / 注释 `:139`）、`feishu.redirect_uri`（生效 `:56` / 注释 `:57`）、`wechat.redirect_uri`（生效 `:75` / 注释 `:76`）、`ollama`（`:126-133` 整段被注释，只留一个 ngrok 地址）全部采用这个模式。一个文件里同时躺着 6 组「本机版 / 生产版」互斥配置块，靠人工注释切换，且**当前主干停在生产版**——其中 `database` 指向的是测试库（见上文澄清，可接受），但 `image.local_dir: /app/data/images` 在开发机上根本不存在，本机上传图片必然失败；`feishu` / `wechat` 的 `redirect_uri` 也停在公网 IP，本机 OAuth 回调走不通。

---

## 3. P0 — 凭据管理

### 3.1 被 git 跟踪的 `backend/config/config.yaml`

`git ls-files --error-unmatch backend/config/config.yaml` 确认已跟踪。内含：

| 行 | 内容 |
|----|------|
| `:11` | `auth.access_secret: "u8K9x2L1n4Q7v5Z0m3P6r9Y2b5X8j1W4"` |
| `:23` | `admin.jwt_secret: "moe-admin-local-jwt-change-me"` |
| `:28` | `admin.bootstrap.password: "admin123"` |
| `:51` | 飞书 `app_secret` |
| `:81` | 微信 `app_secret` |
| `:256` | MySQL root `password: "123456xxZ."` |

`backend/deploy/config.yaml:45`（已 gitignore）用**同一个 `123456xxZ.` 作为 VPS root SSH 口令**——一个口令同时是公网 MySQL root 与公网 SSH root。

### 3.2 Android 签名口令的明文 fallback

```kotlin
// android/app/build.gradle.kts:27,29
storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "moe123456"
keyPassword   = System.getenv("KEY_PASSWORD")      ?: "moe123456"
```

`release.jks` 本身未入库（正确），CI 也通过 `secrets.KEYSTORE_BASE64` 注入（正确，见 `flutter-release.yml:73-79`）。但 fallback 意味着**签名口令本身是公开常量**，一旦 jks 文件从任何渠道流出即可直接签发正式包。

### 3.3 对照组：仓库里已有做对的范例

`.github/workflows/flutter-release.yml:73-110` 全程使用 GitHub Secrets（`KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_PASSWORD` / `MOE_ADMIN_API_BASE` / `MOE_ADMIN_USERNAME` / `MOE_ADMIN_PASSWORD`），没有任何明文。**说明团队具备这个能力，只是后端配置没有走同一条路。**

### 3.4 为什么密钥只能写在 yaml 里：env 通道残缺

全仓**没有统一的 env 覆盖层**（无 `godotenv` / `viper.AutomaticEnv` / `BindEnv`，已验证）。所有 env 读取都是调用点手写 `os.Getenv`：

| 环境变量 | 读取位置 | 问题 |
|----------|----------|------|
| `MOE_LLM_API_KEY` | `pkg/moe/runtime/config_load.go:40`、`wiring/config_override.go:51`、`adapter/moeconfig/inference.go:46` | **三处独立实现** |
| `MOE_LLM_BASE_URL` / `MOE_LLM_API_STYLE` / `MOE_LLM_MODEL` | `config_override.go:25,32,44` + `inference.go:21,28,39` | `14370f93` 新增，**两处逐行重复** |
| `MOE_AUTH_ACCESS_SECRET` | `config_override.go:111`、`utils/auth_jwt_config.go:59` | 两处 |
| `MOE_ADMIN_JWT_SECRET` | `utils/admin_jwt.go` | 一处 |
| `MOE_OSS_ACCESS_KEY_ID` / `_SECRET` | `internal/biz/media/store_oss.go` | 一处 |
| `MOE_LIFE_INTERACTION_ENABLED` | `internal/biz/life/tick.go` | 一处 |
| `MOE_DEPLOY_*`（6 个） | `deploy/config/config.go` | deploy-agent 专属 |

**完全没有 env 通道、只能改 yaml 的项**：`database.*`、`feishu.app_secret`、`wechat.*`、`admin.jwt_secret`、`admin.bootstrap.*`、`runtime.http_port`、全部 `moe.*` 开关、`image.oss.bucket/endpoint`。

> 这正是 §3.1 的**成因**：不是「忘了用环境变量」，而是这些字段根本没有环境变量可用。
>
> `14370f93` 的提交信息写着「重构LLM配置加载，支持环境变量优先的统一配置」，但实际是**在两个文件里各加了一遍相同的 `os.Getenv`**，把重复实现从 1 处扩大到 2 处。方向对，落点分散。

---

## 4. P1 — 同一事实的多份副本

### 4.1 API 地址 `47.106.175.49:8888`

**运行时真被读取的：**

| 文件:行 | 说明 |
|---------|------|
| `lib/utils/config.dart:22,25` | Flutter `productionUrl` / `developmentUrl` |
| `backend/config/config.yaml:34,56,75,138,161` | **同一文件内写了 5 遍**（api / feishu.redirect / wechat.redirect / app_client / image） |
| `backend/api/etc/moe.yaml:37` | go-zero 片段的 `Image.PublicBaseUrl` |
| `moe-admin/deploy/nginx-lan.conf:7,29,39,49,58` | upstream + **4 份重复的 `proxy_set_header Host`** |
| `website/official/js/landing.js:9` | 官网反馈 API |

合计 **6 个文件、14 处**。换域名或迁机器时必须全部同步，其中 nginx 的 4 份 Host 头最易漏（漏了会导致后端拼出的绝对 URL 指向错误主机，且不报错）。

纯文档/示例副本另有 9 处（`backend/deploy/config.example.yaml:42,51`、`docs/dev/app-release-cheatsheet.md:65,88`、`docs/dev/moe-admin.md:114,117`、`docs/dev/飞书OAuth授权验证指南.md:16`、`docs/dev/飞书通知与绑定.md:53,186`、`docs/dev/n100-pipeline.md:3`、`website/official/README.md:55`、`backend/utils/media_public_base_test.go:11-20`）。

### 4.2 端口 SSOT 被越界

`docs/dev/ports.md` + `backend/devports/ports.go` 是一个**做得不错**的端口注册表，明确预留 `19010–19019`。但：

| 端口 | 硬编码位置 | 是否在 ports.md 表内 | 第三批后状态 |
|------|-----------|---------------------|-------------|
| `18888` | `moewiring/config.go:169`（`KratosInternalHTTPPort()`） | ✗ | ✅ **已随死函数删除**，Go 代码里 0 处可执行命中（仅剩一条说明注释） |
| `19032` | `moewiring/config.go:184,189`（`KratosAdminBaseURL()` / `KratosPilotBaseURL()`） | ✗（超出 19010–19019 预留段） | ✅ **已随死函数删除**，2 处兜底消失 |
| `6633` | `config.yaml:103`、`api/etc/moe.yaml:17` | ✗ | 未处理（`moe.yaml` 残留值仍会经 §5.2 的「非空才覆盖」静默生效） |
| `11434` | `config.yaml:97`、`llminference/client.go:70` | ✗ | 未处理（`ResolveAPIStyle` 的端口嗅探，见 §6 表末行） |

`19032` 还同时出现在 `internal/conf/moe/v1/pilot.pb.go:229`、`api/vip/v1/vip_read.pb.go:27`、`api/moe/v1/moe_grpc.pb.go:60,378` 的注释与生成物里，以及 `openapi.yaml:14370,14415`。第三批之后，全仓剩余的 10 处 `19032` 命中**全部是注释、测试 fixture 或 `.pb.go` 生成物里的注释**，生产代码的可执行兜底路径里已经没有这两个无监听者的端口；这些生成物命中要等 proto 重新生成才会消失，不影响运行。端口注册表本身仍未被强制。

---

## 5. P1 — 真源冲突：改了配置但不生效

`backend/config/config.yaml:5` 自称「统一配置（SSOT，PK-13）」。原分析列出 5 类破口，截至 2026-09-08 第三批后**只剩 5.1、5.2 两类未处理**（5.3、5.4 已随死代码删除而消除，5.5 是已修复的写回 bug）：

### 5.1 Agora 段的唯一真源不是 SSOT

`api/etc/moe.yaml:11` 定义了 `Agora:` 段，而 `config.yaml` 中**完全不存在** `agora`（已 grep 确认）。`config_override.go` 也没有对应分支。→ 语音通话凭据的唯一真源是那个被称作「片段」的文件，直接违反 SSOT 声明。

### 5.2 「非空才覆盖」导致片段残留值生效

`config_override.go:14-126`（`ApplyUnifiedConfigOverrides`）的所有分支都是 `if v := ...; v != "" { 覆盖 }`。因此 `api/etc/moe.yaml` 里的残留值会在 `config.yaml` 未显式设置时**静默生效**，例如 `moe.yaml:17` `BaseUrl: http://127.0.0.1:6633`、`:19` `TimeoutSeconds: 300`。（行号较原分析各上移 1，因第三批删掉了同文件第 5 行的 `Timeout: 600000`。）

### 5.3 Go 硬编码短路 yaml ✅ 已消除（2026-09-08 第三批，见 §15.2 B 组）

本节原状：`moewiring/config.go` 里有一族 go-zero→Kratos 迁移期的过渡开关，它们**恒定 `return true`** 或在某个开关为真时强制改写其它开关的返回值，使 yaml 里的同名键完全失去作用。原文记录的短路点是 `KratosPilotReadEnabled()`（3 处 `return true`）、`KratosPureEnabled()` 为真时强制 `KratosHTTPFrontEnabled` / `KratosGRPCManaged` / `KratosSuperGRPCNative` 全部为真、强制 `fallback = false`，以及恒定 `return true` 的 `KratosPK8GoctlRetired()` / `KratosPureHTTPWithoutLegacy()`；另有 7 个键（`kratos_internal_http_port`、`kratos_pilot_read_enabled`、`kratos_http_front_enabled`、`kratos_grpc_managed`、`super_grpc_retired`、`pilot_process_deprecated`、`kratos_hybrid_http_fallback`）在 `config.yaml` 里根本不存在，只能走 Go 默认值。

**处置结果**：这 15 个函数逐个核实调用方后**全部删除**（其中 8 个零调用方，其余的调用方本身也是死代码），`config.go` 从 191 行降到 80 行、只剩 8 个函数。因此「yaml 写了但不生效」和「配置文件里看不到也改不动」这两类破口在本节范围内已不存在——上述 7 个幽灵键的读取逻辑随函数一起消失。`config.go` 现在的唯一职责是 `*_api_in_process` 装配开关族（`IsSet` 语义，见 §12.3 第 2 条），它们的键全部真实存在于 `config.yaml`。

**仍未消除的同类问题**：`config_override.go:73`、`:97` 仍保留 `image.publicbaseurl` / `Image.PublicBaseUrl`（以及 OSS 段的同名驼峰变体）这类永不可能命中的别名——viper 会把查找键小写化，所以「三键并查」实际只有两键，驼峰那一支是纯死代码（详见 §12.1 表）。属第 2 步 `apiconfig` 收敛的范围。

### 5.4 同一个键有两条读取路径 ✅ 已消除（2026-09-08 第三批，遗留一个待决项）

本节原状：`KratosAdminBaseURL()` 先查 `moeconf.LoadBootstrap()`（另一份基于 proto 的加载器），未命中再回落 `moeViper()`，最后兜底 `http://127.0.0.1:19032`。而 `config.yaml` 写的是 `kratos_admin_base_url: "http://127.0.0.1:8888"`。同一个键、两个 loader、三个可能结果——其中那个硬编码兜底端口还没有任何监听者。

**处置结果**：`KratosAdminBaseURL()` 本身零外部调用方（唯一调用方是同批删除的 `KratosPilotBaseURL()`，而后者唯一调用方是 `wire_mode.go` 里那 4 个薄封装之一），因此整条双路径连同 `19032` 兜底一起删除。「两个 loader 读同一个键」这个破口在本节范围内已不存在。

**遗留（需要你决定，见 §15.3）**：`KratosAdminBaseURL()` 是 `moeconf.LoadBootstrap()` 的 4 个调用方之一，且那 4 个全在被删的死函数里——`moeconf` 包现在**零导入方**（98 + 27 行）。连带 `config.yaml` 的 `moe.kratos_pure_enabled` / `moe.kratos_admin_base_url` 两个键也空转了（唯一读者是 `moeconf/load.go:86`）。两键已在 yaml 里就地标注，包本身的删除建议并入第 2 步与 `utils.InitConfig()` 一起做，不单独删。

### 5.5 已确认的写回 bug（管理台保存配置静默失效）✅ 已修复

> **状态：已修复。** 当前工作区 `admin_runtime_config.go:99-109` 写的是蛇形键，并留了注释说明原因：
>
> ```go
> // 键名必须是 config.yaml 实际使用的蛇形键；写成 Image.PublicBaseUrl 会被 viper
> // 小写化为无下划线的 publicbaseurl 死键，运行时优先读 public_base_url，改动静默丢失。
> v.Set("image.public_base_url", trimURL(*patch.ImagePublicBaseUrl))
> v.Set("image.local_dir", strings.TrimSpace(*patch.ImageLocalDir))
> v.Set("image.max_bytes", *patch.ImageMaxBytes)
> ```
>
> 下面是修复前的形态，保留作为「为什么 §12 的统一读取器不能只看蛇形键」的证据。

```go
// backend/utils/admin_runtime_config.go（修复前）
:79   ImagePublicBaseUrl: trimURL(firstViperString(v, "image.public_base_url", "Image.PublicBaseUrl")),  // 读
:100  v.Set("Image.PublicBaseUrl", trimURL(*patch.ImagePublicBaseUrl))                                   // 写
```

读的是 `image.public_base_url`（`config.yaml:161` 的实际键），写的是 `Image.PublicBaseUrl`。viper 会将其小写化为 `image.publicbaseurl`——**一个永不被读取的新键**。后果：管理台保存后界面提示成功，`config.yaml` 里多出一个重复键，原值不变，改动静默丢失。

**这个 bug 对 §12 的统一读取器有直接影响**：任何缓存式加载器都必须在写回后被显式失效，否则「保存成功但读到旧值」会以另一种形式复活。`backend/pkg/conf` 为此提供了 `Reload()`，管理台写回路径迁移时必须调用它。

---

## 6. P2 — 死配置与摆设开关

> **进度更新（2026-09-08，含当日审计复核）**：下表多数项已清掉，勿重复处理——
> `backend/api/etc/super.yaml` 已删；`lib/config/moe_api.json` + `lib/services/remote_api_config_service.dart` 整条链已删；
> `FeatureFlags.showLocalModelSettings` 与 `FeatureFlags.companionSingleActiveBondPhase1` 已从 `lib/constants/feature_flags.dart` 移除；
> pet 模块死配置（`assets/pet/config/*.json` 10 个 + `lib/services/pet_career_config.dart`）已删；
> `MOE_SUPER_RPC_ENDPOINT` 注释承诺已随 `api.super_rpc_endpoints` / `api.super_rpc_timeout_ms` 整块从 `config.yaml` 删除而消除；
> `_runtimeProductionBaseUrl` 间接层已删，`initRemoteProductionBaseUrl()` 已更名为 `initBaseUrl()`。
> **`backend/.env` 一行已失效**：复核发现该文件磁盘上不存在、git 历史里也从未入库（`.gitignore:99-100` 已覆盖 `.env` / `.env.*`），原分析针对的是一个本地未跟踪文件。
> **两个同名 `AppConfig` 已消除**：`lib/utils/config.dart` 的类改名为 `ApiEnvConfig`，`api_service.dart` / `main.dart` 里的 `as moe_launch_config` 别名随之删掉（见 §14.2）。
> **第三批（2026-09-08）更新**：`api.timeout_ms` 整条链已删（6 个文件，见 §15.2 A 组）；`moe.*_api_in_process` 开关族经实测**不是死配置**——20 个键对应 **40 处真实装配调用点**，收敛成一个键要改遍每个域的装配路径，属「改动大、收益中」，本批未动（前提纠正见 §15.1）；同批还清掉了 `moewiring/config.go` 里 15 个零调用方的 Kratos 过渡开关与整条 `wireKratosNotes` 链。
> **仍未处理**：`moe.*_api_in_process` 的收敛（含把 `game` / `notify` / `life` 三个隐藏开关显式化），归入第 2 步调用点迁移。

| 项 | 状态 | 证据 |
|----|------|------|
| `backend/.env` | ✅ **一行已失效**：磁盘上不存在，git 历史里也从未入库 | `ls backend/.env` → No such file；`git log --all -- backend/.env` → 空；`.gitignore:99-100` 已覆盖 `.env` / `.env.*` |
| `backend/api/etc/super.yaml` | ✅ **已删**。原 37 字节、零 Go 引用，却被文档当作 CORS/监听真源 | 删除后 `go build ./...` 通过；悬空文档引用已修（见 §9.2） |
| `MOE_SUPER_RPC_ENDPOINT` | ✅ **已删**。原只存在于 `config.yaml:35` 的注释里，却指导运维去设一个无人消费的环境变量；连同 `api.super_rpc_endpoints`（已注释）与 `api.super_rpc_timeout_ms`（活键但零读者）整块移除 | `grep -rn 'super_rpc_timeout_ms\|MOE_SUPER_RPC_ENDPOINT' backend/ --include='*.go'` → 0；注意 `moe.pilot.super_rpc_endpoint` 是**另一个键**，`moeconf/load.go:62` 仍在读，保留 |
| 20 个 `moe.*_api_in_process` | ⚠️ **不是死配置，是冗余**（第三批实测纠正）：`config.yaml:198-217` 全部为 true（`single_process` 在 `:219`，同为 true），兜底默认值 `defaultInProcessEnabled()`（`moewiring/config.go:40-42`）也是 true → **20 个键的信息量等于 1 个键**。但它们**各有真实调用点**：全仓 40 处 `if moewiring.XxxAPIInProcessEnabled() { ctx.XxxApp = … }` 形态的装配分支 | 收敛成 1 个键要改遍 40 处调用点、覆盖每个域的装配路径，属「改动大、收益中」，故第三批未动，归入第 2 步（详见 §15.1） |
| 隐藏的 3 个开关 | `moe.game_api_in_process`（`api_game.go:13`）、`moe.notify_api_in_process`（`api_notify.go:10`）、`moe.life_api_in_process`（`api_life.go:10`）代码在读，yaml 里没写 | ✅ **已验证工作正常**：只能靠默认值，但冒烟启动日志第 11 行列出了全部 22 个已装配域，含这三个（见 §15.4）。问题是「配置文件里不可见」，不是「不生效」——处置方式是把三键补进 yaml，与上一条合并做 |
| `lib/config/moe_api.json` + `RemoteApiConfigService` | ✅ **整条链已删**。原无调用方：`lib/main.dart:195` 调的方法只读 `AppConfig`、不访问网络 | 删除后 `flutter analyze` 无 error/warning；方法已更名 `initBaseUrlFromAppConfig()`（见下一行） |
| `api.timeout_ms` | ✅ **已删**（第三批 A 组）：原为**只写不读**——`wiring/config_override.go:68` 灌进 `apiconfig.Config.Timeout`，全仓无任何读者。整条链跨 6 个文件一并清除：`config.yaml` 的键 · `api/etc/moe.yaml:5` 的 `Timeout: 600000` · `apiconfig.Config.Timeout` 字段 · `config_override.go` 的写入分支 · `pkg/conf.API.TimeoutMS` 字段 · `conf_test.go` 的 fixture | **方法论记录**：`grep -rn '\.Timeout\b' backend/ --include='*.go'` 命中的三处 `cfg.Timeout` 属 `llminference.Config`（`time.Duration`），与本键（`int64`）毫无关系——**命中不等于消费**，必须确认接收者类型。LLM 超时实际由 `llm_inference.timeout_seconds` 决定，`config.yaml` 已就地注释指向它 |
| 15 个 Kratos 过渡开关 | ✅ **已删**（第三批 B 组）：`moewiring/config.go` 里 `KratosPureEnabled` / `KratosHTTPFrontEnabled` / `KratosGRPCManaged` / `KratosSuperGRPCNative` / `KratosHybridHTTPFallback` / `SuperGrpcRetired` / `KratosPK8GoctlRetired` / `KratosPilotReadEnabled` / `KratosPureHTTPWithoutLegacy` / `PilotProcessDeprecated` / `KratosInternalHTTPPort` / `Kratos{Admin,Vip,AdminInsights}HTTPEnabled` / `Kratos{Pilot,Admin}BaseURL`。文件 191 → 80 行，导入从 4 个降到 2 个 | **逐个实测调用方**（不是看 grep 命中）：8 个零调用方；`KratosPK8GoctlRetired` 的唯一调用方自己也是死的；`KratosPureEnabled` 那 5 个「调用方」全在这族死函数内部。连带消灭 `18888` ×1、`19032` ×2 的硬编码兜底（见 §15.2 B 表） |
| `wireKratosNotes` 整条链 | ✅ **已删**（第三批 C 组）：`wiring/wire_mode.go`（`git rm`，19 行 4 个薄封装）+ `wire_platform.go` 里的函数本体与 `fmt` 导入 + `wire_svc.go:56` 的调用点 | 该函数只往启动日志写 note，而它依赖的三个闸（`kratos_admin_insights_http_enabled` 等）对应的 yaml 键**根本不存在** → 恒 false → **一条 note 都没输出过**。冒烟启动的 46 行日志里零条 kratos note 即为实证（见 §15.4） |
| `FeatureFlags.showLocalModelSettings` | ✅ **已删**（原 0 处引用） | `grep -rn 'showLocalModelSettings' lib/` → 0 |
| `FeatureFlags.companionSingleActiveBondPhase1` | ✅ **已删**。原仅出现在 `companion_service.dart:605` 的注释里，该注释已改写为不依赖此常量 | `grep -rn 'companionSingleActiveBondPhase1' lib/` → 0 |
| `FeatureFlags.showExperimentalFeatures` | 无直接判断，仅用于派生 `showAutoGlm`（`showLocalModelSettings` 已删，派生对象只剩一个） | `feature_flags.dart:19,25` |
| `FeatureFlags.showGachaFeatures` | 仅 1 处挡路由（`app_routes.dart:223`） | 半死 |
| `_runtimeProductionBaseUrl` | ✅ **已删**。原为残留间接层：local 模式为 null，online 模式直接赋 `_configuredOnlineUrl`，恒等于配置值 | `baseUrl` getter 改为直接返回 `_configuredOnlineUrl`，行为等价（被删字段在 local 模式下根本不被读取）；方法两次更名 `initRemoteProductionBaseUrl()` → `initBaseUrlFromAppConfig()` → `initBaseUrl()`，最终名不再暗示「远程拉取」或依赖已改名的 `AppConfig` |
| 两个同名 `AppConfig` 类 | ✅ **已消除**：`lib/utils/config.dart:14` 的类改名为 `ApiEnvConfig`，`api_service.dart:29` 的 `as moe_launch_config` 别名与 `main.dart:15` 的同类别名一并删除。现在全仓只剩 `lib/config/app_config.dart` 一个 `AppConfig`（第三方 LLM 密钥的安全存储），基址开关唯一入口是 `ApiEnvConfig.isProduction` | `grep -rn 'class AppConfig' lib/` → 1 处；`grep -rn 'moe_launch_config' lib/` → 0。**注**：`应用配置与全局常量分层约定.md` 要求的「环境基址搬到 `lib/config/**`」属批次 3 的结构性调整，本轮只解决同名冲突（见 §14.2、§9 表） |
| `assets/pet/config/*.json` | ✅ **已删**（10 个 JSON + `lib/services/pet_career_config.dart` + `pubspec.yaml:146` 的资源声明）。pet 模块已于 `0ff0ab1b` 删除 | `git ls-files assets/pet/config \| wc -l` → 0；`flutter analyze` 无 error |
| `ResolveAPIStyle` 的端口嗅探 | `llminference/client.go:70` 在 `api_style` 未设置时按 URL 是否含 `:11434` 判定协议 | 属兜底而非主路径，风险较低，但 `api_style` 已存在时应移除隐式 magic |

---

## 7. P1 — 环境切换靠改源码

### 7.1 Flutter：`const bool` + 硬编码内网 IP

```dart
// lib/utils/config.dart:16,22,25
static const bool isProduction = false;                              // 切环境 = 改源码
static const String productionUrl = 'http://47.106.175.49:8888';
static const String developmentUrl = 'http://192.168.124.36:8888';   // 换网络即失效
```

文件自己的注释承认「修改后请完整重启 App（Stop + Run），不要只热重载」。没有 `--dart-define`、没有 flavor、没有 env 文件。提交 `96d7a612 更新线上环境` 就是这么做的。

### 7.2 Android buildType 与 Dart 环境完全脱钩

`android/app/build.gradle.kts:45-58` 其实**已经建立了环境区分**：`debug` 带 `applicationIdSuffix = ".dev"`（可与正式包共存），`release` 走签名 + minify。但 Dart 侧的 `isProduction` 与 buildType 无任何关联。

> **后果**：可以构建出一个 `release` 签名的正式包，而它连的是 `192.168.124.36` 内网地址。`moe_ui.xml`（`14370f93` 误提交的 UI dump）里 `package="com.example.moe_social.dev"`，且界面上正显示「模型服务调用失败，请检查 API Key、模型和额度后重试」——这类问题的排查成本正来自环境与构建类型不绑定。
>
> **进度更新（2026-09-08）**：这条后果**已从「静默发生」变成「CI 失败」**。`.github/workflows/flutter-release.yml` 第 7 步在构建 APK 前断言 `ApiEnvConfig.isProduction == true`，读到 `false` 就以 `::error::` 终止工作流，不会上传 Release、也不会推飞书通知。
> buildType 与 Dart 环境**仍然脱钩**，这是刻意的：`.cursor/skills/moe-flutter/SKILL.md` §1.9、`product-reference.md:59`、`app-usability-upgrade-plan.md` P0-A 三条既有规则都禁止提前绑定 `kReleaseMode` 或引入 `--dart-define` 一类构建变量（开发期确实需要 release 包连本地后端，见 `SKILL.md:305` S1「不记 Fail」）。所以本轮选择**不改语义、只加检查**，方案取舍见 §14.1。

### 7.3 发布前需人工记得关闭的开关

```dart
// lib/constants/feature_flags.dart:22
/// Android 异地联机网络实验。开发阶段直接开启；发布前关闭。
static const bool showGameNetworkLab = true;    // ← 当前为 true，靠人记
```

引用点：`app_routes.dart:371`、`settings_advanced_section.dart:121`。该开关会注册一个 VPN Service（`GameNetworkVpnService.kt`，462 行）——发布包中携带实验性 VPN 能力而无卡点校验。

同类风险：`showGameFeatures = false`（`:8`，控互动故事入口）与 `arenaGamePrototype = true`（`:12`，控星辉 Arena 路由）语义正交但**都叫 game**，极易误关。

### 7.4 VPS 侧：用一次性脚本原地改 yaml

```bash
# backend/scripts/vps-switch-companion-model.sh（14370f93 新增）
old = 'memory_model: "qwen3:4b"'
new = 'memory_model: "qwen2.5:3b-instruct"'
if old not in text:
    raise SystemExit("memory_model pattern not found")
```

这个脚本是**配置已分叉的直接物证**：它假定 VPS 上的值是 `qwen3:4b`（仓库里当时并不是），只能成功执行一次，且硬编码了绝对路径 `/root/gowork/backend/config/config.yaml`。提交进仓库后它对任何人都不可复用，只留下一条「曾经手工改过服务器配置」的记录。

---

## 8. P1 — 四套部署链互不知情

| 链路 | 目标 | 问题 |
|------|------|------|
| `.github/workflows/n100-deploy.yml` | n100 小主机 | `:37` 构建 `./cmd/moe-social-stack`，而该文件头注释（`cmd/moe-social-stack/main.go:1-6`）写着「开发专用……生产请用 cmd/moe-social」；产物却命名 `bin/moe-social` 并装成 systemd 服务（`:38-39`）。`backend/Makefile:70,87,95` 一律用 `./cmd/moe-social`。stack 版还多一个前置条件：无条件调用 `devlauncher.FindBackendRoot()`，失败即 `log.Fatal`（`main.go:31-34`） |
| n100 配置交付 | `~/moe-runtime/config/config.yaml` | `deploy/n100/bootstrap.sh` 首次从 `backend/config/config.yaml` 拷一份，随后声明「pipeline will not overwrite it」→ **机器配置与仓库配置从第一天起永久分叉**。`moe-social.service` 用相对路径 `-f config/config.yaml` + `WorkingDirectory=%h/moe-runtime`，与 `docker-compose.binary.yml:7` 的显式传参风格不一致 |
| moe-admin 发布 | `/var/www/html/ops` | **两条链写同一目录且互不知晓**：`moe-admin/deploy/sync-lan.ps1:12,24`（`sudo rm -rf /var/www/html/ops/*` + tar 解包）vs `n100-deploy.yml:57`（`rsync -a --delete dist/ /var/www/html/ops/`）。任一条执行都会整目录删除另一条的产物；且权限模型冲突（sudo vs 非 sudo runner），`bootstrap.sh` 里设的 `chown www-data` 会被打乱 |
| 云 VPS | `47.106.175.49` | 第三套：`backend/deploy/config.yaml` + `docker-compose.binary.yml`，由 deploy-agent（`:19010`）驱动 |

**两个 compose 文件的配置模型不对等：**

| | `docker-compose.yml` | `docker-compose.binary.yml` |
|---|---|---|
| 配置来源 | `Dockerfile:16` `COPY config/config.yaml` → **烤进镜像** | `volumes: ./config` → 挂载 |
| `api/etc` | `Dockerfile:15` COPY | 挂载 |
| `MOE_LLM_*` env | **0 个** | 4 个（`:9-13`，`14370f93` 新增） |
| 网络 | `ports: 8888:8888` | `network_mode: host`（`:14`，同时移除了 ports 映射） |

即：走 Dockerfile 那条路径部署，新加的 env 覆盖能力**完全不可用**，且密钥随镜像分发。

---

## 9. P2 — 文档与代码不符（会直接误导人）

| 文档 | 声称 | 实际 |
|------|------|------|
| `docs/dev/环境配置说明.md:13` | `developmentUrl = 'http://127.0.0.1:8888'` | ✅ **已修**：整节重写，代码样例改为与 `lib/utils/config.dart` 逐字一致（`http://192.168.124.36:8888`），并补了「按构建目标该填什么」的对照表（真机 = 局域网 IP、Android 模拟器 = `10.0.2.2`、iOS 模拟器/Web = `127.0.0.1`）。同类错误在 `API调试指南.md`、`快速调试步骤.md` 里也有，一并修掉（见 §14.4） |
| `docs/dev/环境配置说明.md`（后端服务节） | 「后端监听与 CORS 见 `config.yaml`、`backend/api/etc/super.yaml`」 | ✅ **已修**：`super.yaml` 已删，该文档现已不含此引用 |
| `docs/dev/飞书OAuth授权验证指南.md:16,26` | 要求 `redirect_uri` 与 `lib/config/moe_api.json` 的 `api_base_url` 指向同一台 API | ✅ **已修**：`moe_api.json` 已删，两处改指 `lib/utils/config.dart` 的 `ApiEnvConfig.productionUrl`；`:93` 同类引用一并修掉 |
| `docs/dev/moe-admin.md:114,117` | deploy target `api_base_url: http://47.106.175.49:8888` | 与 n100 链路（`192.168.124.77`）并存，未说明何时用哪个。**仍未处理** |
| `backend/config/config.yaml:35` 注释 | 「Docker 推荐用 compose 环境变量 `MOE_SUPER_RPC_ENDPOINT=rpc:8080`」 | ✅ **已修**：该注释连同 `api.super_rpc_endpoints` / `api.super_rpc_timeout_ms` 整块删除（三者全仓零读者） |
| `lib/services/api_service.dart:192` 注释 | 「勿再使用 `api_env.json`」 | ✅ **已修**：`api_env.json` 仓库中已不存在，该引用已删 |
| `ApiService.initRemoteProductionBaseUrl()` | 方法名暗示「从远程拉取生产基址」 | ✅ **已修**（两次更名）：`initRemoteProductionBaseUrl()` → `initBaseUrlFromAppConfig()` → **`initBaseUrl()`**，同步改 `main.dart:195`、`auth_service.dart:93`、`环境配置说明.md`。最终名不再依赖已改名的 `AppConfig` 类 |
| `docs/dev/应用配置与全局常量分层约定.md` | `lib/config/**` 放行为、`lib/constants/**` 放数据定义 | 环境基址这个最核心的配置仍在**第三个位置** `lib/utils/config.dart`（用户明确要求「暂时都在 config 里面维护」）；**类名冲突部分已解决**——该类改名 `ApiEnvConfig`，全仓只剩一个 `AppConfig`。把文件搬到 `lib/config/**` 属结构性调整，仍在批次 3 |
| `backend/docs/private_messages.md:52` | 图片落在 `Image.LocalDir`（`api/etc/super.yaml`），可被 `config.yaml` 的 `image.local_dir` 覆盖 | ✅ **已修**：改指 `api/etc/moe.yaml:36`（`Image` 段确在此文件）；同行 `:53` 的 `getimagelistlogic`（已随 go-zero logic 层删除）改指 `internal/biz/media/image.go:67` |

### 9.1 更严重：文档教的启动命令已整体失效 ✅ 已完成（2026-09-08）

> **状态：已清理。** 本节保留作为「清理了什么」的清单，整改完成后按文档维护约定应整节删除。
>
> 实际改动分四类：
>
> 1. **启动脚本**（3 个）：`scripts/start-admin.sh`、`scripts/start-admin.ps1`、`scripts/stop-admin.sh`。
>    其中 `start-admin.{sh,ps1}` 原先是**静默失效**的——`start_bg` 把命令丢到后台并**无条件写 pidfile**，
>    所以两条指向已删除 `super.go` 的调用失败得无声无息，脚本照样打印「后端已启动」和访问地址。
>    也就是说 `make admin` 从来没真正把后端拉起来过。现已改为单条 `go run ./cmd/moe-social -f config/config.yaml -migrate`
>    + `go run ./cmd/deploy-agent`，并在输出里加了日志路径提示，让下次失败可被发现。
> 2. **Go 运行时提示串**（3 处，用户能看见）：`deploy/handler/devhub.go:31`（浏览器里的 502 正文）、
>    `internal/biz/admin/runtime_overview.go:54,86`（管理台 API 的 `processes_note`）、`cmd/migrate/main.go:1`。
>    这三处原先都在指导用户去跑已删除的命令。
> 3. **HTML 工具页**（2 个）：`docs/dev/tools/rpc-monitor.html`、`docs/dev/devtools.html` —— 已标注页面无数据源。
> 4. **文档**（11 份）：`ports.md`、`moe-social-runtime.md`、`admin-rpc-runtime-guide.md`、`new-api-kratos.md`、
>    `环境配置说明.md`、`cross-platform-dev.md`、`飞书通知与绑定.md`、`moe-admin.md`、
>    `security-and-stability-backlog.md`、`goctl-generation-hygiene.md`（加归档头）、`kratos-legacy-api-migration.md`。
>
> 顺带实测出的结论（已写进上述文档）：后端**只监听一个端口** `runtime.http_port`（8888），无 gRPC；
> `8080` / `19011` / `18888` / `19032` / `6633` 五个端口**已无任何监听者**。其中 `18888` / `19032` 的硬编码兜底已在第三批随死函数一并删除（见 §15.2），生产代码里再无引用；`6633` 仍作为 `api/etc/moe.yaml` 的残留值存在（见 §5.2）。

Kratos 迁移删除了 go-zero 时代的双进程入口——`backend/rpc/` **目录已不存在**，`backend/api/super.go` **已删**（注意 `backend/api/` 下仍有 `.go` 文件，是 `api/<domain>/v1/*.pb.go` 一类的 protoc 产物，不是入口）。但大量文档仍在指导读者使用这些入口：

| 文档引用的命令 | `backend/Makefile` 中是否存在 | 引用位置 |
|----------------|------------------------------|----------|
| `make rpc` | ✗ | `ports.md:7`、`环境配置说明.md:30`、`cross-platform-dev.md:9,32`、`moe-social-runtime.md:89` |
| `make api` | ✗ | `ports.md:8`、`环境配置说明.md:29`、`cross-platform-dev.md:9`、`moe-social-runtime.md:89` |
| `make rpc-debug` | ✗ | `ports.md:11`、`cross-platform-dev.md:40`、`admin-rpc-runtime-guide.md:191` |
| `make moe-admin-dev` | ✗ | `ports.md:10` |
| `make dev` / `make rpc-migrate` | ✗ | `cross-platform-dev.md:31,32` |
| `go run super.go` / `go run ./rpc/super.go` | ✗（文件已删） | `ports.md:7`、`security-and-stability-backlog.md:68,69`、`飞书通知与绑定.md:229`、`moe-admin.md:60`、`moe-social-runtime.md:55` |
| `make moe-social` / `make admin` / `make deploy-agent` / `make db-migrate` / `make gen` / `make check` / `make build-linux` / `make dev-docs` | ✅ | — |

**影响面**：`docs/dev/README.md` 把 `环境配置说明.md` 和 `ports.md` 列为「优先阅读（当前有效）」，`docs/README.md` 的「本地跑起来」快速入口也指向它们。也就是说，**新人按官方索引的第一份文档操作，第一条命令就会失败**。

现存唯一正确入口是 `cd backend && make moe-social`（单进程 Kratos HTTP，`Makefile:69-70`），这一点在 `AGENTS.md` 里是对的，但在 `docs/dev/` 下被上述 6 份文档覆盖。

> 这不是「文档写得旧」的小问题：`ports.md` 同时是端口 SSOT（见 §4.2），它既登记了失效命令，又漏登记了真正的外部依赖 `11434`（n100 上的 Ollama）与 `3306`（测试库）。一份 SSOT 同时存在**多写**和**漏写**两类错误。
>
> 补记（实测修正）：本节初稿曾把 `18888` / `19032` / `6633` 也列为「实际在用但漏登记」，这是错的——三者**没有任何监听者**，只作为硬编码兜底活在零调用者的死函数里（`moewiring/config.go:169,184,189`、`config.yaml:103` 的 `game_base_url` 占位）。它们已被写进 `ports.md` 新开的「已无监听者的端口」表，而不是在用端口表。
>
> 再补（第三批后）：上述 `moewiring/config.go:169,184,189` 三处兜底**已随死函数删除**，按这些行号已找不到东西；`ports.md` 的「已无监听者的端口」表保留，因为它记录的正是「这些端口不该再被任何配置或代码引用」这一事实。

### 9.2 删文件的连带影响：悬空引用全仓扫描 ✅ 已完成（2026-09-08）

§6 / §10.1 那批删除（`moe_api.json`、`remote_api_config_service.dart`、`pet_career_config.dart`、`assets/pet/config/*`、`api/etc/super.yaml`、`.env`、`cover.out` 等）本身是干净的——`go build ./...`、`make check`、`flutter analyze`（38 条全为 info，无 error/warning）、`flutter test` 相关 3 个文件 8/8 通过，无任何编译期悬空。

但**文档与内联脚本不看编译器**。按已删文件名逐个全仓扫描后，发现三类残留：

**一、悬空引用（已修）**

| 位置 | 原引用 | 改为 |
|------|--------|------|
| `docs/dev/飞书通知与绑定.md:50,201` | `lib/config/moe_api.json` | `lib/utils/config.dart`（`AppConfig.productionUrl` / `developmentUrl`） |
| `docs/dev/飞书通知与绑定.md:200` | `backend/api/internal/handler/user/feishu_auth_handler.go` | `backend/internal/server/transport/oauth.go`（`backend/api/internal/` 整个目录已随 go-zero 移除） |
| `docs/dev/飞书OAuth授权验证指南.md:16,26,93` | `moe_api.json` | `AppConfig.productionUrl` |
| `CODE_WIKI.md:129` | `lib/config/` → `app_config.dart`、`moe_api.json` | 只剩 `app_config.dart` |
| `backend/docs/private_messages.md:52,53` | `api/etc/super.yaml`、`getimagelistlogic` | `api/etc/moe.yaml:36`、`internal/biz/media/image.go:67` |
| `docs/dev/llm-inference-and-memory-vision.md:13` | go-zero `etc/super.yaml` | `api/etc/moe.yaml`（该文件 `:17` 确有 `LLMInference` 驼峰段） |
| `assets/pet/lpc/README.md:9` | `assets/pet/config/lpc_prototype.json`、`docs/dev/pet-lpc-pipeline.md` | 两者均已不存在，改指仍在的 `scripts/pet/compose_lpc_hero.ps1` |
| `docs/dev/devtools.html:130` | 「可自动读 `lib/config/moe_api.json`」 | 改为「API 基址可在看板内输入框修改」 |
| `docs/dev/memory-system-dashboard.html:374,433-443,1000` | `fetch("../../lib/config/moe_api.json")` | 整个 `tryLoadProjectApiConfig()` 连同调用点删除（必然 404，走 `!r.ok` 直接 return，已无作用；`apiBase` 兜底由 `loadLocal()` 末尾覆盖，删后行为不变） |

**二、两个真功能性 bug（已修，不只是文案）**

`docs/dev/tools/deploy-ops.html` 的「运维部署中心」有两处与后端契约脱节，会**主动误导操作者**：

1. **远程巡检面板恒报假错**（`:1395-1398`）。前端读 `c.compose_rpc_env_ok` / `c.config_rpc_endpoints_ok` / `c.api_container_rpc_env_ok` / `c.rpc_config_ok` / `c.legacy_super_docker_yaml`，而 `RemoteCheckResult`（`backend/deploy/runner/remote_inspect.go:12-24`）**一个都不返回**——API→RPC 分体部署退役时后端已把这些字段删了。`undefined` 恒为假，于是面板永远显示「`MOE_SUPER_RPC_ENDPOINT` 未配置/错误」「API→RPC 配置就绪: 否」，把人派去修一个不存在的问题；同时后端**真返回**的 `binary_exists`、`container_running` 反而没被展示。已改为只渲染结构体实际字段。
2. **远程配置下拉与白名单不一致**（`:773`）。下拉提供 `api/etc/super.yaml`，但后端白名单 `allowedRemoteConfigPaths`（`backend/deploy/runner/remote_config.go:14-21`）里没有它 → 选中必然被 `ValidateRemoteConfigName` 拒绝、报「读取失败」；而白名单里真有的 `api/etc/moe.yaml` 与 `Modelfile` 反倒没有选项。已与白名单逐项对齐。

**三、整篇失效的文档（加历史横幅，未改正文）**

这两份不是个别行错，而是**前提整体消失**，逐行修反而会把历史决策改没，因此按仓库已有先例（`docs/product/签到等级管理后台系统实施文档.md:4`）加警示横幅：

| 文档 | 失效证据 |
|------|----------|
| `docs/dev/memory/README.md` | 记忆子系统已于 `14edac0e`（2026-06-29「移除了一些不需要的能力」）整体删除，68 文件 / 2116 行。`backend/pkg/memory`、`backend/rpc`、`lib/memory` 三个目录均不存在，`HybridSearch` / `SearchFacing` / `BuildProfiles` / `HybridSearchUserFacingMemories` 全仓零命中 |
| `docs/dev/kratos-p5-split-deploy.md` | 分体部署已无法装配：`backend/rpc` 不存在、`backend/api` 根目录无 Go 文件（切流清单第 1、2 步的 `go build ./rpc` / `go build ./api` 跑不了）；`runtime.grpc_listen` 零读者且 `config.yaml` 无此键；`/migration` 端点与 `p5_super_runtime_pct` 零命中（第 6 步跑不了）。**但** `moe.register_moe_grpc` / `use_moe_grpc`（`moeconf/load.go:76-77`）与 `moe.super_grpc_retired`（`moewiring/config.go:141`，默认 true）三个闸门仍被读取，横幅里特别写明「保持单进程默认值，不要按本文改成 false」 |

**四、生成物按生成流程处理**

`moe-admin/public/dev/codegraph/*.json` 里仍挂着已删的 `remote_api_config_service` 节点。该目录 README 明确写「Do not hand-edit. Regenerate」，故执行 `node scripts/codegraph/gen_all.mjs` 重新生成（5 个文件、+2525/−499 行，均为 JSON 有效）。

> 两点说明：① 这个大 diff 是生成器**追平数月漂移**的结果，不只是本轮删除——例如 `pet.json` 反而 +244 行，是在补录 `assets/pet/moe_content/avatar/layers/slots/` 下新增的 PNG。若要提交，建议**单独成一个 commit**，别和配置治理混在一起。
> ② 生成器扫描范围有限：`gen_backend.mjs` 只扫 `backend/internal/service` 与 `backend/internal/biz`，**不含 `backend/pkg/`**，所以新建的 `backend/pkg/conf` 不会出现在 `backend.json` 里。这是生成器的既有局限，不是本轮改动造成的。

> 未处理的同类项：`.qoder/repowiki/**` 下也有多处引用已删文件，但该目录**未被 git 跟踪**（`git ls-files .qoder/` 为空），属工具自动生成的本地知识库，不在整改范围。


---

## 10. P3 — 仓库卫生

### 10.1 被提交的调试产物 ✅ 已基本清理（2026-09-08，已随 `8037287e` 入库）

> **状态**：下表 6 项中，`moe_ui.xml`、`cover.out`、`.pet_exists_check.txt`、`.cursor/_hero_orig.txt` 已删除；
> 3 个 `.DS_Store` 已不再被跟踪（`git ls-files | grep -i DS_Store` 为空）；
> `.gitignore` 已补 `/cover.out`（原第 67 行只覆盖 `backend/cover.out`）与 `duplication-report/`；
> `duplication-report/` 下被跟踪的 6 个报告文件已从 git 移除，目录本身仍在磁盘上，现在是**被忽略的本地产物**——这是正确处理，报告可重新生成。
> 下表保留作为「当初错在哪」的记录。

| 文件 | 来源 | 说明 |
|------|------|------|
| `moe_ui.xml` | `14370f93` | Android `uiautomator dump` 的单行 XML，仓库根目录，尾部还带着 `UI hierchary dumped to: /dev/tty`（含拼写错误） |
| `.cursor/_hero_orig.txt` | `3074fbe6` | 280 行原始文本备份 |
| `cover.out`（根目录） | — | 10 字节。`.gitignore:67` 只忽略了 `backend/cover.out`，**根目录这个漏网** |
| `duplication-report/` | — | `jscpd-report.json` / `.html` / `analysis.html` 全部被跟踪 |
| `.pet_exists_check.txt` | `0ff0ab1b` | pet 模块已删，检查脚本产物留存 |
| 3 个 `.DS_Store` | — | 根目录 / `backend/` / `moe-admin/` |

未被跟踪但也未忽略的本地噪音：`--css`（47KB，`.gitignore:156` 已覆盖）、`flutter_01.log`（`*.log` 已覆盖）。

### 10.2 游离的嵌套 git 仓库

`moe_social_backend/` 含自己的 `.git/` 与一个 README，既未跟踪也未 ignore，导致 `git status` 永久挂着一行 `?? moe_social_backend/`。

### 10.3 脚本目录 6 处

`tool/`（2 个文件）· `tools/`（1 个子目录）· `scripts/` · `backend/scripts/` · `backend/deploy/scripts/` · `moe-admin/scripts/`

其中 `tool/` 与 `tools/` 是**单复数并存的两个不同目录**，无 README 说明分工。

### 10.4 backend 文档 4 份职责重叠

`backend/README.md` · `backend/LAYOUT.md` · `backend/DEPLOY.md` · `backend/架构说明.md`（265 字节，中英混名的第 4 份）

### 10.5 AI 指令与规则 4 套体系

`AGENTS.md` · `code_review.md` · `CODE_WIKI.md`（17KB）· `.cursor/rules/`（6 个 `.mdc`）· `.cursor/skills/`（16 个）· `.cursor/LESSONS.md` · `.qoder/`（`repowiki` / `specs` / `better-harness`）

`AGENTS.md` 自称「规则入口」指向 `.cursor/rules/moe-social-engineering.mdc`，但 `docs/README.md` 的「开发规范」行同时列了 `AGENTS.md`、`moe-social-unified.mdc`、`code_review.md` 三者，未说明优先级。

---

## 11. 建议整改路线

分 6 批，每批可独立验收、独立提交。**批次 1 与 2 是其余批次的前置**。

### 批次 1 — 建立 env 通道（前置，不改行为）

| 动作 | 验收标准 |
|------|----------|
| 新建单一配置加载入口 —— **已建：`backend/pkg/conf`**（不是原提案的 `internal/platform/confloader`）。放在 `pkg/` 不是语言约束——Go 的 internal 规则允许 `backend/` 下任何包（含 `utils/`、`pkg/moe/*`）导入 `backend/internal/*`；真正的理由是它是**只依赖 stdlib + viper 的叶子**，与仓库既有的叶子库惯例一致（`pkg/llminference`、`pkg/processmem`、`pkg/handdraw`），放 `internal/platform/` 会让 `utils/` 反过来去够 wiring 层。收敛全部 `os.Getenv`；`config_override.go` / `moeconfig/inference.go` / `runtime/config_load.go` 三处重复实现改为调用它。**第 1 步已完成且为纯新增（零调用点迁移）**，设计与迁移顺序见 §12 | 迁移完成后 `grep -rn 'os.Getenv("MOE_' backend/` 只命中 `pkg/conf` 一个包；当前 `grep -rn 'viper.New()' backend/ --include='*.go'` 仍有 19 处待收敛（不含 `utils.InitConfig()` 全局单例，也不含 2 处读 `deploy/config.yaml` 的） |
| 为 §3.4 列出的「只能改 yaml」字段补齐 env 覆盖：`database.*`、`feishu.app_secret`、`wechat.*`、`admin.jwt_secret`、`admin.bootstrap.*`、`image.oss.*` | 每个字段都有对应 `MOE_*` 变量，且 env 优先于 yaml |
| `android/app/build.gradle.kts:27,29` 移除 `?: "moe123456"` fallback，改为缺失即构建失败 | 无 env 时 `./gradlew assembleRelease` 明确报错而非用默认口令 |

### 批次 2 — 拆配置：模板入库，真值出库

| 动作 | 验收标准 |
|------|----------|
| `backend/config/config.yaml` → `config.example.yaml`（脱敏模板，入库）+ `config.yaml`（加入 `.gitignore`） | `git ls-files backend/config/` 只有 example |
| 按 §2 的环境清单拆出 per-env 覆盖片段，或统一由 env 注入；**任何内网 IP（`192.168.*`、`127.0.0.1`）不得出现在入库文件中** | `grep -rn '192\.168\.\|47\.106\.' --include='*.yaml' .` 在入库文件里为空 |
| ~~修 `admin_runtime_config.go:100` 键名 → `image.public_base_url`~~ **✅ 已修复**，见 §5.5 | 管理台保存后 `config.yaml` 不再新增 `publicbaseurl` 重复键 |
| 把 `Agora` 段并入 `config.yaml`，或明确 `api/etc/moe.yaml` 的职责边界并写进文档 | `config.yaml` 覆盖全部运行时字段，SSOT 声明成立 |
| 轮换全部临时凭据（用户已计划）——**在批次 2 落地后再换**，否则新密钥会再次被写进同一份被跟踪的文件 | 新凭据只存在于 env / gitignore 文件 |

### 批次 3 — 地址与环境单点化

| 动作 | 验收标准 |
|------|----------|
| 后端只保留一个 `runtime.public_base_url`，`api.public_base_url` / `feishu.redirect_uri` / `wechat.redirect_uri` / `image.public_base_url` / `app_client.public_api_base_url` 全部由它派生 | `config.yaml` 中该 IP 只出现 1 次 |
| `nginx-lan.conf` 的 4 份 `proxy_set_header Host` 改为 `$proxy_host` 或单一变量 | Host 头不再逐 location 复制 |
| ~~Flutter 改用 `--dart-define=API_BASE_URL=...` + 构建类型绑定，删除 `isProduction` 常量~~ **❌ 提案已否决**，改为「CI 发布前断言」——见 §14.1。原提案与三条既有规则冲突（`moe-flutter/SKILL.md` §1.9 勿提前强制 `kReleaseMode`、`product-reference.md:59` 手动切、`app-usability-upgrade-plan.md` P0-A 不引入构建变量）；**已落地的替代方案**：`flutter-release.yml` 第 7 步断言 `ApiEnvConfig.isProduction == true`，`test/utils/config_test.dart` 另断言 `productionUrl` 不是内网地址 | `isProduction` 仍是唯一真源（`flutter build apk --release` 依旧需要改源码，这是刻意保留的开发期能力）；但「忘记切就发版」不再静默——CI 直接红 |
| `showGameNetworkLab` 纳入同一构建期注入机制，并在 CI 加发布卡点（release 构建时断言实验开关为 false） | 无法构建出携带实验 VPN 能力的 release 包。**注**：后半句的「CI 加发布卡点」已被本轮的断言步骤证明可行，可复用同一个 step 追加检查 |
| ✅ **已完成（2026-09-08）**：删除 `lib/config/moe_api.json` 与 `lib/services/remote_api_config_service.dart`；`initRemoteProductionBaseUrl()` 更名为 `initBaseUrl()`（连带删掉 `_runtimeProductionBaseUrl` 间接层）；`AppConfig` 类改名 `ApiEnvConfig`，消除与 `lib/config/app_config.dart` 的同名冲突 | 死链清除，方法名/类名不再误导。前端基址仍靠改 `lib/utils/config.dart` 源码切换（用户明确要求「暂时都在 config 里面维护」），但发版有 CI 断言兜底 |

### 批次 4 — 清死配置与摆设开关（删除清单 ✅ 已完成，收敛清单 ✅ 4 项中 3 项已完成）

**删除清单 ✅ 全部完成（2026-09-08）**：`backend/api/etc/super.yaml` · `config.yaml:35` 关于 `MOE_SUPER_RPC_ENDPOINT` 的注释（连同 `api.super_rpc_endpoints` / `api.super_rpc_timeout_ms` 整块）· `_runtimeProductionBaseUrl` 间接层 · `api_service.dart:192` 关于 `api_env.json` 的注释 · `assets/pet/config/*.json`（10 个）+ `lib/services/pet_career_config.dart` + `pubspec.yaml` 资源声明 · `.pet_exists_check.txt` · `lib/config/moe_api.json` + `lib/services/remote_api_config_service.dart`。
其中 `backend/.env` 一项经复核为**空指**：磁盘上不存在、git 历史里从未入库（`.gitignore:99-100` 已覆盖），原分析针对的是一个本地未跟踪文件。
连带影响（悬空引用、两个 deploy-ops 真 bug、两份整篇失效文档、codegraph 重生成）见 §9.2。

**第三批新增删除（2026-09-08，见 §15.2）**：`api.timeout_ms` 整条链（6 个文件）· `moewiring/config.go` 的 15 个 Kratos 过渡开关（文件 191 → 80 行）· `wireKratosNotes` 整条链（`git rm wiring/wire_mode.go` + 删函数本体与 `fmt` 导入 + 删 `wire_svc.go:56` 调用点）。

`FeatureFlags`：✅ 已删除 0 引用的 `showLocalModelSettings`、`companionSingleActiveBondPhase1`；**未做**：把 `showGameFeatures` / `arenaGamePrototype` / `showGachaFeatures` 改名以消除「都叫 game」的歧义。

**验收标准**：`config.yaml` 中每个键都能在 Go 代码里找到读取点；每个 `FeatureFlags` 常量都有 ≥1 处 `if` 引用。
⚠️ **当前未达标**：`moe.kratos_pure_enabled` 与 `moe.kratos_admin_base_url` 两键的唯一读者是 `moeconf/load.go:86`，而 `moeconf.LoadBootstrap()` 的 4 个调用方全在第三批删掉的死函数里 → 该包**零导入方**，两键空转。两键已在 yaml 就地标注，处置随「是否删除 `moeconf` 包」的决定一并落地（见 §15.3）。

**收敛清单（第三批后仅剩 1 项，属第 2 步调用点迁移）**：

| 原计划项 | 现状 |
|---------|------|
| 20 个 `moe.*_api_in_process` → 1 个（`single_process`），并把 `game` / `notify` / `life` 三个隐藏开关显式化 | ⏳ **未做**。规模已实测纠正：不是「20 处分支」而是 **40 处装配调用点**，且这三个隐藏开关经冒烟启动验证工作正常（见 §15.1、§15.4）。属「改动大、收益中」 |
| 恒定 `return true` 的 `KratosPK8GoctlRetired()` / `KratosPureHTTPWithoutLegacy()` 直接删除并把调用点固化为 true | ✅ **已删**（第三批 B 组）。无需固化调用点——实测两者的调用方本身也是死代码 |
| `moewiring/config.go` 中约 10 个 yaml 里不存在的 kratos 键，要么补进 `config.yaml`，要么删掉读取逻辑 | ✅ **已按「删掉读取逻辑」处置**（第三批 B 组，共 15 个函数）。选择删除而非补键的依据：这些键描述的是 go-zero→Kratos 的过渡形态，而迁移已完成，补进 yaml 等于把过期状态显式化 |
| `api.timeout_ms` 只写不读，随 `apiconfig` 一并清除 | ✅ **已删**（第三批 A 组，跨 6 个文件）。未等到第 2 步的 `apiconfig` 收敛，因为该字段零读者、删它不需要动任何调用点 |

`FeatureFlags`：✅ 已删除 0 引用的 `showLocalModelSettings`、`companionSingleActiveBondPhase1`；**未做**：把 `showGameFeatures` / `arenaGamePrototype` / `showGachaFeatures` 改名以消除「都叫 game」的歧义。

**验收标准**：`config.yaml` 中每个键都能在 Go 代码里找到读取点；每个 `FeatureFlags` 常量都有 ≥1 处 `if` 引用。

### 批次 5 — 部署链收敛

| 动作 |
|------|
| `n100-deploy.yml:37` 改为构建 `./cmd/moe-social`（与 Makefile 一致）；若确需 stack 版，请在 workflow 里写明原因 |
| `sync-lan.ps1` 与 `n100-deploy.yml:57` **二选一**，删掉另一条；若都必须保留，改为写不同目录再原子切换软链 |
| 仓库内提供 n100 的脱敏 config 模板，消除 `bootstrap.sh` 造成的永久分叉；改为「模板入库 + 机器上只放 secrets」 |
| 两个 compose 文件合并，或让 `docker-compose.yml` 也支持 `MOE_LLM_*` env；确认 `network_mode: host` 是有意选择（它使容器共享宿主全部网络，且令 `ports:` 失效） |
| `vps-switch-companion-model.sh` 删除——它是一次性动作的残留，正确的做法是批次 2 的 env 覆盖 |
| 端口注册表强制化：~~`18888` / `19032`~~ / `6633` / `11434` 要么登记进 `devports/ports.go` + `ports.md`，要么改为从配置读取。**第三批后范围缩小**：`18888` / `19032` 的硬编码兜底已随死函数删除，两者不再需要登记（`ports.md` 的「已无监听者的端口」表继续作为「不得再引用」的记录）；真正待处理的只剩 `6633`（`api/etc/moe.yaml` 残留值，见 §5.2）与 `11434`（n100 上的 Ollama，`config.yaml:97` + `llminference/client.go:70` 的端口嗅探） |

### 批次 6 — 仓库卫生与文档对齐

- 删除 `moe_ui.xml`、`.cursor/_hero_orig.txt`、根目录 `cover.out`、`duplication-report/`、3 个 `.DS_Store`
- `.gitignore` 补 `/cover.out`（现有第 67 行只覆盖 `backend/cover.out`）、`duplication-report/`、`*.xml` dump、`.DS_Store`
- 处置 `moe_social_backend/` 嵌套仓库：确认后删除，或加入 `.gitignore`
- `tool/` 与 `tools/` 合并为一个目录并加 README 说明分工
- `backend/` 4 份文档（README / LAYOUT / DEPLOY / 架构说明.md）合并
- 修正 §9 表中全部文档漂移项
- **清除 §9.1 的失效启动命令** ✅ **已完成（2026-09-08）**：`ports.md`、`环境配置说明.md`、`cross-platform-dev.md`、`moe-social-runtime.md`、`security-and-stability-backlog.md`、`admin-rpc-runtime-guide.md`、`飞书通知与绑定.md`、`moe-admin.md`、`new-api-kratos.md`、`goctl-generation-hygiene.md`、`kratos-legacy-api-migration.md` 中的 `make rpc` / `make api` / `make rpc-debug` / `make moe-admin-dev` / `make dev` / `make rpc-migrate` / `go run super.go` 已全部改为实际存在的目标（后端唯一入口 `cd backend && make moe-social`），并连带修了 3 个启动脚本与 3 处 Go 运行时提示串（清单见 §9.1）。
  端口表的处理**与本条原计划不同**：实测 `18888` / `19032` / `6633` **没有任何监听者**，只是死函数里的硬编码兜底，因此没有加进「在用端口」表，而是在 `ports.md` 里新开了「已无监听者的端口」表并注明原因；真正需要补的只有 `11434`（n100 上的 Ollama，`config.yaml:97`）和 `3306`（测试库）两个外部依赖。
  **第三批后**：`18888` / `19032` 的死函数兜底已删除，两者从「代码里还有引用」变为「代码里零可执行引用」；`6633` 未动。
- `应用配置与全局常量分层约定.md` 补充「环境基址」归属，解决两个 `AppConfig` 同名冲突
- 明确 AI 指令体系优先级（`AGENTS.md` / `.cursor/rules/` / `.qoder/` / `code_review.md` / `CODE_WIKI.md`）

---

## 12. 统一配置加载器（`backend/pkg/conf`）

> **状态：第 1 步已落地（2026-09-08），第 2 步进行中（6 个子步骤完成 1 个）。**
> 第 1 步是纯新增、零调用点迁移 —— 因此从 2026-09-08 到 2026-09-09 期间，`pkg/conf`（1338 行，含 561 行测试）**一直是死代码**：`go build` 与 `go test` 全绿，但零个外部导入者。当时 `grep -rn '"backend/pkg/conf"' backend/ --include='*.go'` 为空即为证。
> **2026-09-09 第 2.1 步落地后，`backend/utils` 成为第一个导入者**（见 §16）。
> ⚠️ 教训：新建统一层不等于收敛完成。**「加载器建好了」和「调用点迁过来了」是两件事，中间隔着一整天没人发现的死代码。** 判断收敛进度只能看反向依赖数，不能看新包是否存在、是否能编译、测试是否通过。

### 12.1 要解决的问题

同一份 `backend/config/config.yaml` 被 **18 处**独立打开：17 个遗留的 `viper.New()`（分布在 **14** 个文件）+ `utils.InitConfig()` 的全局 viper 单例。每处都：

> **计数修正（2026-09-08 第三批后实测）**：原文写「20 处 = 19 个 `viper.New()` + `utils.InitConfig()`」，多算了 1 处。实测 `grep -rn 'viper.New()' backend/ --include='*.go'` 共 **22** 处命中，需排除 4 处：`deploy/config/config.go` 的 2 处（读的是**另一个** `deploy/config.yaml`）、`pkg/conf/load.go:193` 的 1 处（这是**新加载器自己**，不是遗留读取点）、`pkg/conf/config.go:3` 的 1 处（注释文字）。余下 18 处才是遗留读取点。
> 第三批**没有改变这个计数**：已核对 HEAD，被删函数所在的 `moewiring/config.go` 在改动前后都只有 1 处 `viper.New()`（在 `moeViper()` 里），被整文件删除的 `wire_mode.go` 是 0 处。
> **文件数修正（2026-09-09 复核实测）**：原文写「18 处分布在 16 个文件」。18 处正确，但 16 个文件**与 18 处不同口径** —— 既然把 `deploy/config/config.go` 的 2 处从站点数里排除了，就必须把这个文件也从文件数里排除，正确值是 **15 个文件**（raw grep 22 处命中 / 16 个文件，减 `deploy/config/config.go` 后为 18 处 / 15 个文件）。这与 §15.5 记录的是同一类错误：**分子与分母必须在同一口径上**。
> **第五批后计数（2026-09-09 实测）**：raw grep 从 22 降到 **21** 处命中 —— `moeconf/load.go:27` 随整包删除消失。排除项不变（仍是 `deploy/config/config.go` 2 处 + `pkg/conf/load.go:193` + `pkg/conf/config.go:3` 注释），故遗留站点为 **17 处 / 14 文件**，总独立打开点 **18 处**。同时 `utils.InitConfig()` 的**生产**调用方从 4 个降到 **3 个**（`cmd/migrate/main.go:28`、`moesocial/run_http_only.go:18`、`utils/db.go:36`；`moeconf/load.go:23` 已随包删除，另有 `utils/feishu_test.go:57` 一处测试调用不计入）。这是 §12.5 序 6 的第一次实际缩减。

- 各自硬编码一遍 `SetConfigName("config")` + 三条 `AddConfigPath`（`./config`、`../config`、`../../config`）；
- 各自实现一遍回退链，且**互不一致**：

| 事实 | 迁移前的状态 |
|------|--------------|
| LLM 端点解析 | `moeconfig/inference.go:13` 认全部 4 个 `MOE_LLM_*` 环境变量；`pkg/moe/runtime/config_load.go:14` **只认 `MOE_LLM_API_KEY`**。同一件事两条链，Bot 调度与 Companion 对同一个环境变量的反应不同 |
| 环境变量优先级 | LLM / App JWT / 管理台 JWT 是「env 优先」；OSS 密钥（`store_oss.go:28-34`）是「文件优先、env 兜底」。**两种相反的约定并存**，没有任何一处文档说明 |
| `image.*` 键名 | `config_override.go:73-110` 用 `firstNonEmptyString(v, "image.local_dir", "image.localdir", "Image.LocalDir")` 三键并查。实测 viper 会把查找键小写化，所以第 2、3 个参数**是同一个键**，三键并查实际只有两键；而驼峰变体在全仓任何 YAML 里都不存在（`api/etc/moe.yaml` 的驼峰键走的是 `yaml.Unmarshal`，不经 viper）→ **纯死代码** |
| 端口口径 | `runtime.http_port`（int）与 `moe.production.external_http_port`（string）表达同一件事，`moesocial/startupconfig.go:68-79` 负责在两者间回退 |
| 键名写错的后果 | 静默取零值。§5.5 的写回 bug 就是这么来的 |

### 12.2 第 1 步交付了什么

```text
backend/pkg/conf/
  config.go    256 行  Config 及各段结构体（mapstructure tag = YAML 键名）
  load.go      207 行  Get / Load / LoadFile / Reload / Path / Err / IsSet / ResetForTest
  derive.go    311 行  解析方法：环境变量覆盖 + 历史键回退的唯一实现处
  conf_test.go 562 行  16 个用例，含对真实 config.yaml 的冒烟
```

依赖只有 stdlib + `github.com/spf13/viper` + `backend/pkg/llminference`（也是叶子），可被 `utils/`、`pkg/*`、`internal/*` 三层直接引用。

`make check` 与 `go build ./...` 均通过；`go test ./pkg/conf/ -count=1` 16/16 通过。

### 12.3 三个必须显式处理的语义陷阱

1. **viper 把所有键小写化。** `database.parseTime` 在 `AllSettings()` 里是 `parsetime`，所以 tag 必须写 `mapstructure:"parsetime"`；写成 `parse_time` 会静默拿到 `false`，DSN 里就少了 `parseTime=true`，MySQL 驱动的时间扫描随之出错。已有专门用例 `TestTypedMirror` 盯这一条。
2. **装配开关需要 `IsSet`，不能只看 bool 值。** `moe.<domain>_api_in_process` 的语义是「未设置则继承 `single_process || api_in_process`」，而不是「默认 false」。类型化结构体里的 `bool` 分不清「显式 false」和「没写」，所以 `state` 保留了原始 `*viper.Viper` 供 `IsSet` 使用（`load.go:16-27` 有注释说明）。用例 `TestDomainInProcess` 用 `vip_api_in_process: false` 与未出现的 `post` 同时断言两种情况。
3. **缓存必须在写回后失效。** §5.5 那类 bug 换个形式就会复活。`Reload()` 是为此存在的，管理台 `ApplyRuntimeConfigPatch` 迁移时必须调用它。用例 `TestReload` 断言「改文件后 `Get()` 仍返回旧值、`Reload()` 后才返回新值」——两头都要测，只测后者会漏掉缓存根本没生效的情况。

### 12.4 刻意的行为决定（原 2 项，第三批后仅剩 1 项需签字）

- **`Inference()` 取环境变量的超集**（认全部 4 个 `MOE_LLM_*`）。这意味着 `pkg/moe/runtime` 迁过来之后，`MOE_LLM_BASE_URL` / `MOE_LLM_API_STYLE` / `MOE_LLM_MODEL` **将开始影响 Bot 调度**（此前只有 `MOE_LLM_API_KEY` 生效）。这是有意的收敛，不是回归；已在 `derive.go` 的 `Inference()` 注释里写明。
- ~~**`KratosAdminBaseURL()` 的兜底从 `19032` 改为 `runtime.http_port`。**~~ **❌ 已作废（第三批）**：该函数连同它的两处 `19032` 兜底已被整体删除（零外部调用方，见 §15.2 B 组），迁移目标不存在了。因此第 2 步**只剩 1 项需要签字的行为变更**（上面那条 `Inference()` 取环境变量超集）。
  > **歧义澄清（2026-09-09 第五批）**：上一句删掉的是 **`moewiring` 的遗留函数**。`pkg/conf/derive.go:250` 那个**同名新方法当时并没有删**，它带着「兜底改为 `runtime.http_port`」的注释一直留到第五批——实测 `conf.KratosAdminBaseURL()` 形式的外部调用方为 **0**，即它是一个**生下来就没有调用方的迁移目标**（目标已在第三批消失）。第五批连同另外 3 个 `Kratos*Enabled()` 方法、9 个 `Kratos*` 类型化字段一并删除。<br>⚠️ 同时删掉的还有它的专属用例 `TestKratosGates`（原 `conf_test.go:419-438`，注释自称「复现 moewiring 的总闸语义」）——**这是一个「用测试把死代码保住」的实例**：用例断言的是已删除函数的行为，所以只要它在，那 4 个零调用方的函数就删不掉、`go test` 也永远是绿的。§16.2 的教训是「测试通过 ≠ 已接线」，这一条是它的镜像：**测试通过也可能只是死代码有人看守**。

### 12.5 第 2 步：调用点迁移顺序

按**消费者数量升序**推进，每步可独立提交、独立验收：

| 序 | 目标 | 消费者 | 备注 |
|----|------|--------|------|
| 1 | `database.*` → `conf.DSN()` | 1（`utils/db.go:96`，原 `:96-105`） | ✅ **已完成（2026-09-09，见 §16.1）**。运行时验证过新旧 DSN 逐字节相同、两侧读到同一个 `config.yaml` |
| 2 | `image.*` / `app_client.*` / `auth.*` / `api.*` / `runtime.*` | 各 1–2 | ✅ **驼峰死别名已于第五批删完**（见 §17.4）：`config_override.go` 里 **11 处** `image.*` 多键并查折叠为单键直读、1 处不可达的 `Image.OSS.ProxyViaAPI` else-if 删除，`firstNonEmptyString` / `firstPositiveInt64` 两个辅助函数随之整体移除（实测 141 行 → 111 行）。**本步只剩**：管理台写回处（`utils/admin_runtime_config.go`）接 `Reload()` |
| 3 | `llm_inference.*` → `conf.Inference()` | ~~5~~ **24 处读取 / 7 文件** | **收益最大**：一次消掉两条不一致的链。⚠️ **原评估「5」与序 6 的「4 个调用者」是同一类低估**（数的是 `viper.New()` 站点，不是读取点）——这是该错误第三次出现。实测 13 个文件提及 `llm_inference.`，其中 4 个只是注释或错误消息字符串（`apicomm/llm_inference_client.go`、`protohttp/moe_extended.go`、`runtime/generate.go`、`runtime/host_metrics.go`），正是 §13.3 的「命中≠消费」；真读取为 24 处 / 7 文件（`moeconfig/inference.go` 10、`wiring/config_override.go` 5、`runtime/config_load.go` 5、`apicomm/inference_props.go` 1、`brain/prompt_memory.go` 1、`brain/topic_analyze.go` 1、`runtime/post_model.go` 1）。<br>✅ **`ollama.*` 回退已于第五批全部删除**（原写 12 处，实测 **15 处**，见 §17.3），本步剩余工作量随之缩小 |
| 4 | `moe.*` 调度器 / 模型 | 5 | `pkg/moe/brain/*` 4 处 + `pkg/moe/runtime/post_model.go` |
| 5 | ~~`moe.kratos_*` / `pilot.*`~~ / `production.*` | ~~多~~ **只剩端口口径** | 原评为「最难」：要吸收 `moeconf.LoadBootstrap()` 的 proto `Bootstrap` 映射，并处置 `moewiring` 里 13 个零调用者的死开关。**第三批已把死开关全部删掉（实测 15 个）**，`moewiring` 只剩 8 个函数、全是活的 `*_api_in_process` 装配开关。<br>✅ **第五批已把剩余部分做完**（见 §17.2）：`moeconf` 整包删除，`MoePilot` + 9 个 `Kratos*` 字段 + 4 个 `Kratos*` 派生方法一并移除，`config.yaml` 的 `moe.kratos_pure_enabled` / `moe.kratos_admin_base_url` 两键删除，孤立的 `internal/conf/moe/v1`（proto + 生成物）与 `gen-moe-conf` 生成链退役。**本步现在只剩 `production.*`**：`external_http_port`（字符串 "8888"）与 `runtime.http_port`（int）表达同一件事，读取点是 `moesocial/startupconfig.go:70-79` 的回退链 + `derive.go:124 HTTPPort()` |
| 6 | 删除 `utils.InitConfig()` 全局单例 | ~~4 个调用者~~ **50 处读取 / 16 个文件** | ⚠️ **原评估严重低估（2026-09-09 实测纠正）**：「4 个调用者」数的只是**调用 `InitConfig()` 的地方**（`cmd/migrate/main.go:28`、~~`moeconf/load.go:23`~~、`moesocial/run_http_only.go:18`、`utils/db.go:35`；第五批删掉 `moeconf` 后**只剩 3 个生产调用方**），但真正**依赖它已被调用**的是全局 viper 单例的 **50 处读取点，分布在 16 个文件**：`utils/` 38 处 / 12 文件（`feishu.go` 6、`feishu_oauth.go` 6、`wechat_oauth.go` 5、`private_message.go` 5、`feishu_contact.go` 4、`feishu_public_config.go` 3、`auth_jwt_config.go` 2、`admin_seed.go` 2、`admin_jwt.go` 2、三个 redirect/flow 各 1），`internal/` 12 处 / 4 文件（`service/user/user_temp_mail.go` 5、`biz/user/oauth_wechat.go` 4、`biz/user/oauth_feishu.go` 2、`biz/admin/dashboard.go` 1）。按配置段分：`feishu.*` 23、`wechat.*` 8、`private_message.*` 5、`temp_mail.*` 4、`admin.*` 4、`auth.*` 3、`api.*` 1。<br>✅ **好消息：类型化侧已完全就绪** —— 实测这 50 处读取涉及 **32 个唯一键，`pkg/conf` 已全部建模**（含嵌套的 `Admin.Bootstrap.Username/Password`，`config.go:69-72`）。所以本步**不缺任何结构体，纯属机械改写 50 处读取点**。<br>✅ **「与 `moeconf` 删除合并做」的建议已于第五批执行**（见 §17.1）：`LoadBootstrap` 的注释写明它「先 InitConfig，再映射 moe 段」，两者本就是同一条链，现已一起收掉 |

第 5 步完成后，`grep -rn 'viper.New()' backend/ --include='*.go'` 应只剩 `deploy/config/config.go`（Deploy Agent 读的是**另一个** `deploy/config.yaml`，不在本次收敛范围内）。

### 12.6 第 3 步（可选，后续）：拆文件

`config.yaml` → `config.yaml`（入库骨架）+ `env.{local,vps,n100}.yaml` + `secrets.example.yaml` / `secrets.yaml`（gitignore）；加载顺序 base → env → secrets → `MOE_*`；`MOE_ENV` 缺省 `local`。这一步与 §11 批次 2 是同一件事，**必须在凭据轮换之前落地**，否则新密钥会再次写进被跟踪的文件。

> **排期（2026-09-08）**：需求方明确「config 的拆分可以晚一点进行调整」，本步**暂缓**。但上面那句约束不变——它必须排在凭据轮换之前，否则新密钥会重复入库。

---

## 13. 2026-09-08 改动审计

对工作区中尚未提交的全部改动做了一次逐条核实：是否与本文档的判断一致、是否留下悬空引用、是否引入行为变化。（审计时这些改动尚未提交，现已入库为 `8037287e` + `3ebcf62d`；要复核请用 `git show`，工作区里已看不到。）

### 13.1 核实为正确的改动（9 项，未作修改）

| 改动 | 核实方式 |
|------|----------|
| `backend/utils/admin_runtime_config.go` 写回键改蛇形（`image.public_base_url` / `local_dir` / `max_bytes`） | 与 `config.yaml` 实际键名逐字对齐；原 `v.Set("Image.PublicBaseUrl", …)` 会被 viper 小写成无下划线的 `publicbaseurl` 死键，改动静默丢失（§5.5）。附带的解释注释准确 |
| `backend/api/etc/super.yaml` 删除 | 零 Go 引用；`apiconfig` 读的是仍然存在的 `api/etc/moe.yaml` |
| `lib/config/moe_api.json` + `lib/services/remote_api_config_service.dart` 删除 | 零 Dart 引用；`initRemoteProductionBaseUrl()` 确实只读 `AppConfig`、不发网络请求，删除不改变行为 |
| `lib/services/pet_career_config.dart` + `assets/pet/config/*.json`（10 个）+ `pubspec.yaml:146` 资源声明删除 | 三者一致（文件、代码、资源声明同步移除，未留下 pubspec 指向空目录） |
| `FeatureFlags.showLocalModelSettings` / `companionSingleActiveBondPhase1` 删除 | 零引用；`companion_service.dart:605` 的注释已同步改写为不依赖被删常量——这一点做得对，否则会变成悬空文档引用 |
| 端口链清理（`moe.proto` / `vip_read.proto` / `devports/ports.go` / `deploy/handler/devhub.go` / `biz/admin/runtime_overview.go` / `cmd/migrate/main.go` / `deploy/scripts/stop-moe-social.{sh,ps1}` / `deploy/config.example.yaml`） | 全部为注释与文案层，无逻辑变更；`:19011` 与 `:8080` 保留在停止脚本里并注明「防御性清扫」是正确取舍（清一个没人监听的端口无害，删了反而漏掉历史残留进程） |
| `scripts/start-admin.{sh,ps1}` / `stop-admin.sh` | 见 §9.1：原脚本因 `start_bg` 无条件写 pidfile 而**静默失败**，`make admin` 从未真正拉起后端 |
| `.gitignore` 新增 `/cover.out` 与 `duplication-report/` | 原第 67 行只覆盖 `backend/cover.out`，根目录那个漏网（§10.1）；报告目录转为被忽略的本地产物是正确处理，可重新生成 |
| `backend/pkg/conf/` 新包（4 文件 1336 行） | add-only，`grep -rn '"backend/pkg/conf"'` → **0 个导入方**，不影响任何现有行为。详见 §12 |

### 13.2 本轮修正的问题

| # | 问题 | 处理 |
|---|------|------|
| 1 | `config.yaml:35-40` 的 `api.super_rpc_*` 整块零读者，且注释仍在指导运维设置同样无人消费的 `MOE_SUPER_RPC_ENDPOINT` | 整块删除。保留 `moe.pilot.super_rpc_endpoint`（**另一个键**，`moeconf/load.go:62` 真在读）。**第三批后补注**：`moeconf` 包已变成零导入方（见 §15.3），该键随之也空转了；键与包的处置绑定在同一个决定上 |
| 2 | `api.timeout_ms` **只写不读**（新查明）：`config_override.go:68` 灌进 `apiconfig.Config.Timeout` 后无人消费 | 本轮先只改注释、指向真正生效的 `llm_inference.timeout_seconds`；**第三批已把整条链删除**（6 个文件：yaml 键、`moe.yaml` 的 `Timeout: 600000`、`apiconfig.Config.Timeout` 字段、`config_override.go` 写入分支、`pkg/conf.API.TimeoutMS`、测试 fixture），未等到第 2 步的 `apiconfig` 收敛——因为零读者意味着删它不需要动任何调用点（见 §15.2 A 组） |
| 3 | `_runtimeProductionBaseUrl` 死间接层 + `initRemoteProductionBaseUrl()` 误导性方法名（§6 / §9 早已登记，本轮才做） | 删字段、更名 `initBaseUrlFromAppConfig()`，同步 `main.dart:195`、`auth_service.dart:93`、`环境配置说明.md:7`。**后续又更名一次为 `initBaseUrl()`**（随 `AppConfig`→`ApiEnvConfig` 改名，见 §14.2） |
| 4 | 9 处指向已删文件的悬空引用 | 见 §9.2 表一 |
| 5 | **`deploy-ops.html` 远程巡检面板恒报假错** —— 读 5 个后端早已不返回的字段，`undefined` 恒为假 | 见 §9.2 表二第 1 条。这是本轮最实质的一处：它会主动把人派去修一个不存在的问题 |
| 6 | **`deploy-ops.html` 远程配置下拉与后端白名单不一致** —— 提供的 `api/etc/super.yaml` 必被拒绝，白名单里真有的两项反而没选项 | 见 §9.2 表二第 2 条 |
| 7 | `docs/dev/memory/README.md`、`docs/dev/kratos-p5-split-deploy.md` 整篇前提已消失 | 加历史横幅，不改正文（见 §9.2 表三）。**这两份是既有腐化，不是本轮改动造成的** |
| 8 | `codegraph/*.json` 仍挂着已删节点 | 按目录 README 要求重新生成，未手改（见 §9.2 表四） |

### 13.3 审计方法

不靠阅读 diff 下结论，每项都用可复现命令核实：

```bash
# 编译期悬空：三个工具链全绿才算「删干净」
cd backend && go build ./... && go vet ./... && make check
flutter analyze --no-pub                      # 38 条全为 info，无 error/warning
flutter test test/utils/config_test.dart test/ai_provider_service_test.dart \
             test/services/llm_api_config_test.dart    # 8/8，覆盖 baseUrl 路径

# 文档/脚本层悬空：编译器看不见的地方，按已删文件名逐个全仓扫
for pat in moe_api.json remote_api_config_service pet_career_config \
           "api/etc/super.yaml" "assets/pet/config" initRemoteProductionBaseUrl \
           api_env.json super_rpc_timeout_ms MOE_SUPER_RPC_ENDPOINT; do
  grep -rn "$pat" --include='*.md' --include='*.html' --include='*.dart' \
       --include='*.go' --include='*.yaml' --include='*.json' \
       docs/ backend/docs/ backend/config/ backend/deploy/ lib/ scripts/ CODE_WIKI.md
done

# 内联 JS 改了也要验语法（HTML 不参与编译）
node -e 'const fs=require("fs"),vm=require("vm");const h=fs.readFileSync(F,"utf8");
  const re=/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi;let m;
  while((m=re.exec(h))) new vm.Script(m[1]);'

# 「只写不读」这类判断必须追到消费者，不能只看有没有 grep 命中
grep -rn '\.Timeout\b' backend/ --include='*.go'   # 再逐个确认 cfg 的静态类型
```

最后一条是本轮最容易踩的坑：`api.timeout_ms` 表面上「有代码在读」（`config_override.go:68`），`grep .Timeout` 也命中三处 `cfg.Timeout`——但那三处的 `cfg` 是 `llminference.Config`（`time.Duration`），与 `apiconfig.Config.Timeout`（`int64`）毫无关系。**命中不等于消费**，必须确认接收者类型。
（注：上述 `config_override.go:68` 是**审计当时**的位置，该写入分支已在第三批连同整条链删除，按此行号已找不到代码；结论与删除记录见 §15.2 A 组。）

### 13.4 尚未开始、且需要先签字的部分

第 2 步（迁移调用点到 `pkg/conf`）**未开始**。它是第一步会在真实调用点改变行为，且 §12.4 原记录了两个刻意的行为收敛需先确认——**第三批之后只剩 1 项**：

1. `Inference()` 取 `MOE_LLM_*` 环境变量的**超集**（认全部 4 个）。迁移后 `MOE_LLM_BASE_URL` / `API_STYLE` / `MODEL` **将开始影响 Bot 调度**（此前只有 `MOE_LLM_API_KEY` 生效）。
2. ~~`KratosAdminBaseURL()` 兜底从 `19032` 改为 `runtime.http_port`~~ **❌ 已作废**：该函数在第三批被整体删除（零外部调用方，见 §15.2 B 组），迁移目标不存在。

第三批对第 2 步的净影响是**范围缩小**：`moewiring/config.go` 从 191 行降到 80 行、只剩 8 个活函数，原评为「最难」的第 5 序（见 §12.5）不再需要处置 15 个死开关。但**新增一项待决**：`moeconf` 包现已零导入方，建议与第 6 序的 `utils.InitConfig()` 删除合并处理，不单独删（理由见 §15.3）。

另有两项已知情况：

- ~~`moewiring/api_post.go:63` 读顶层 `hand_draw_require_moderation`，而 `config.yaml` 把它放在 `runtime:` 下 → 该读取恒为 `false`~~ **✅ 已修（2026-09-08，见 §14.3）**。原判断「修它会改变手绘过审行为」经实测**不成立**：`config.yaml` 里该键的值就是 `false`，与旧的硬编码默认值相同，所以修正键路径后**今日行为零变化**，只是这个开关从此真的接上了。真正的行为变化留给以后把 yaml 改成 `true` 的人——那才是有意的产品决定。
- `pkg/moe/toolaudit` 的 `TestBuildSchemaItemsCoversAllTools`（期望 ≥6 个工具、实得 5）是**既有失败**，已用 `git worktree` 在干净 HEAD 上复现确认与本轮无关。断言和工具列表哪个对属产品判断。

---

## 14. 2026-09-08 第二批：小改动大收益的收拢

用户约束（逐字）：「目前的 ip 配置我打算的是 暂时都在 config 里面进行维护 这样会比较清晰 ，可以先调整一下 现在存在问题 改动比较小但是收益大的地方 ，逐步推进修复工程吧 ，可以进行收拢」。即：**前端 IP 继续留在 `lib/utils/config.dart`**，不做批次 3 的结构搬迁；只挑「改动小、收益大」的问题收拢。

### 14.1 头号问题：发布包指向开发机局域网 IP —— 以及一次被规则否决的实现

**事实链**：`.github/workflows/flutter-release.yml` 打 release APK 时不带任何 `--dart-define`，而 `lib/utils/config.dart` 的 `isProduction` 是硬编码 `false`，`developmentUrl = http://192.168.124.36:8888`。所以**每一个被上传到 GitHub Releases、并通过飞书通知出去的安装包，连的都是开发者本人电脑的内网地址**——外部用户装上后所有请求必然失败，而 CI 全绿、Release 正常发布、通知正常推送。这是 §7.2「后果」那段从推论变成已发生事实的确认。

**我先做错了一版**：第一次实现给 `isProduction` 加了 `kReleaseMode` 回落，并在 CI 里加 `--dart-define=MOE_API_ENV=online`。技术上是标准做法，但做完一轮文档扫描后发现它与三条**既有成文规则**直接冲突：

| 出处 | 原文约束 |
|------|----------|
| `.cursor/skills/moe-flutter/SKILL.md:130`（§1.9） | 勿提前强制 `kReleaseMode` |
| `.cursor/skills/moe-flutter/product-reference.md:59` | API 基址用 `isProduction` 手动切 |
| `docs/dev/app-usability-upgrade-plan.md:90`（P0-A） | 不引入构建变量、CI 覆盖或启动时远程重写地址 |

而且 `SKILL.md:305` 的 S1 场景**明确容忍**「开发期 release 包连开发机」并标注「**不记 Fail**」——也就是说这个「失效模式」在当前阶段是被规则有意允许的。我没有静默覆盖规则，而是停下来把冲突摆给用户，用户选择了「CI 加发布前断言，不改语义」。

**已落地的方案**：

1. `lib/utils/config.dart` 回滚，`isProduction` 保持唯一真源，无 `kReleaseMode` 回落、无 `foundation.dart` 导入。
2. `flutter-release.yml` 新增第 7 步 `Assert release points at online API`，在 Build APK **之前**执行：grep 锚定 `static const bool isProduction = <true|false>` 声明行，值不是 `true` 就打 `::error::` 并 `exit 1`。构建 APK 的命令行恢复为不带 `--dart-define`。
3. `test/utils/config_test.dart` 补上 CI 覆盖不到的另一半（见下）。

**为什么断言不算违反 P0-A**：那一步只**读**源文件、只做判断、不向构建注入任何值、不改任何语义。它既不是「构建变量」也不是「CI 覆盖」——CI 覆盖指的是流水线用变量把地址改写掉，而这里是让流水线在地址不对时**拒绝发版**。已把这段论证写进 `app-usability-upgrade-plan.md` P0-A 的「2026-09-08 补充」，并把 `SKILL.md` §1.9 的规则**保留原文**、只补一句说明「断言是检查而非覆盖」。

**分工（两道防线，缺一不可）**：

| 防线 | 能拦 | 拦不住 |
|------|------|--------|
| CI 第 7 步（grep 源码） | `isProduction` 忘切就发版 | 切了 `true`，但 `productionUrl` 本身写成了内网地址 |
| `config_test.dart` 的 `_isPrivateOrLoopbackHost` | `productionUrl` 是 `127.*` / `10.*` / `192.168.*` / `172.16-31.*` / `169.254.*` / `localhost` / `::1` / `0.0.0.0`，或与 `developmentUrl` 相同 | 运行时才知道的地址不可达 |

第二道尤其关键：`isProduction = true` 但 `productionUrl` 还是内网的话，发布包照样全挂，而**CI 日志看起来一切正常**。测试里另有一条把 `baseUrl`/`getApiUrl()` 一致性写成**不变量**而非钉死具体值，这样为发版翻 `isProduction` 时不需要同步改测试。

断言脚本用 7 个用例实测通过（把 workflow 第 81–98 行原样抽出来、加 CI 默认 shell 的 `set -e` 后逐个跑）：

| # | 输入 | 期望 | 实测 |
|---|------|------|------|
| 1 | `isProduction = true` | 放行 | ✅ PASS，并打印两个 URL |
| 2 | `isProduction = false` | 拦住 | ✅ BLOCK，`::error::…isProduction=false` |
| 3 | 声明整行缺失 | 拦住 | ✅ BLOCK，`isProduction=<未找到声明>` |
| 4 | `dart format` 把 `= true` 折到下一行 | 放行 | ✅ PASS |
| 5 | `lib/utils/config.dart` 不存在 | 拦住 | ✅ BLOCK |
| 6 | 声明写成 `= kReleaseMode`（非字面量） | 拦住 | ✅ BLOCK，`<未找到声明>` |
| 7 | 仓库当前真实文件（`isProduction=false`） | 拦住 | ✅ BLOCK——开发态的树本来就不该能发版 |

**用例 4 抓到了我自己写的一个 bug**：第一版脚本注释声称「容忍空白差异，避免 dart format 换行造成误拦」，但 `grep` 是逐行的，声明一旦被折行就匹配不到 → 报 `<未找到声明>` → **误拦一次正常发版**。已改为先 `tr '\n' ' '` 把换行折成空格再匹配，注释也改成如实描述。方向上这是安全的（误拦而非误放），但会在发版当口逼人 debug CI，所以值得修。

顺带得到的性质：断言是 **fail-closed** 的——凡是读不出字面量 `true`（用例 3/5/6），一律拦下，不存在「解析失败就放行」的路径。

### 14.2 `AppConfig` → `ApiEnvConfig` 改名（消除同名冲突）

全仓曾同时存在两个 `AppConfig`：`lib/utils/config.dart`（环境基址，全 `const`）和 `lib/config/app_config.dart`（第三方 LLM 密钥的安全存储，全 `async`）。两者职责、生命周期、读写方式完全不同，同名靠 `as moe_launch_config` 别名规避——读代码时极易把「同步 const 开关」和「异步安全存储」当成一回事。

已改：`lib/utils/config.dart` 的类改名 `ApiEnvConfig`；`api_service.dart:29`、`main.dart:15` 的导入别名删除（10 处引用同步）；`ApiService.initBaseUrlFromAppConfig()` → **`initBaseUrl()`**（旧名里的 `AppConfig` 已不指这个类，留着会继续误导）；`auth_service.dart:93` 注释、`main.dart:250-251` 启动日志同步。文档层 6 份（`环境配置说明.md`、`app-release-cheatsheet.md`、`飞书OAuth授权验证指南.md`、`飞书通知与绑定.md`、`app-release-backend.md`、`CODE_WIKI.md`）里的 `AppConfig` 按语义分别改为 `ApiEnvConfig` 或明确指向 `lib/config/app_config.dart`。

`app-release-cheatsheet.md` §4 额外补了两条注：**断言步骤不是第四个地址来源**（它只读不写）；别把 `ApiEnvConfig` 和 `AppConfig` 搞混。

### 14.3 `runtime.hand_draw_require_moderation` 键路径（活 bug，但今日零行为变化）

`backend/internal/platform/moewiring/api_post.go` 的 `handDrawRequireModeration()` 原先读顶层键 `hand_draw_require_moderation` 与驼峰别名 `HandDrawRequireModeration`，而 `config.yaml` 把它放在 `runtime:` 段下 → 两个键 `IsSet` 恒为假 → 恒返回硬编码默认值，**把配置改成 `true` 也不会生效**。

已改为读 `runtime.hand_draw_require_moderation`（对齐 `moewiring/config.go` 里 `"moe.api_in_process"` 的既有约定），并删掉驼峰别名——viper 会把所有键小写，`HandDrawRequireModeration` 实际变成 `handdrawrequiremoderation`，永远命中不了。

**用一次性程序实测证明**（临时 `backend/tmp_verify/main.go` 复刻 `moeViper()` 的加载方式，跑完即删）：

```
IsSet(hand_draw_require_moderation)            = false
IsSet(HandDrawRequireModeration)               = false
IsSet(runtime.hand_draw_require_moderation)    = true   GetBool = false
IsSet(moe.single_process)                      = true   GetBool = true   ← 对照组，证明加载器本身没问题
```

因为 yaml 里的值恰好就是 `false`，与旧默认值相同，所以**今日行为零变化**——变的只是这个开关从此真的接上了。这修正了 §13.4 原先「修它会改变手绘过审行为」的判断。同类死键还有 `Image.PublicBaseUrl`（viper 小写成 `image.publicbaseurl`），已在 §5.5 修掉。

### 14.4 文档漂移批量修正（同一类缺陷，一次性扫清）

这一批的共性是：**文档教的机制在代码里已经不存在**，照做会白费时间甚至改错文件。

| 文档 | 原文声称 | 实际 |
|------|----------|------|
| `API调试指南.md` | 改 `lib/services/api_service.dart` 第 50 行的 `Platform.isAndroid` 分支来切地址；`_isProduction` 在「api_service.dart 第27行」；模拟器「自动使用 `10.0.2.2` / `localhost`，无需修改配置」 | 这套按平台分支的机制**整体不存在**。地址只有两个常量，都在 `lib/utils/config.dart`；模拟器不会自动换地址，得自己把 `developmentUrl` 改成 `10.0.2.2` |
| `API调试指南.md` | 生产环境「所有平台统一使用 `http://74fd3e66.r3.cpolar.top`」 | cpolar 隧道早已不用，真源是 `productionUrl` |
| `API调试指南.md:156-158`、`快速调试步骤.md:169-171` | 「设置 `_isProduction = true`」 | 字段已删；改为 `ApiEnvConfig.isProduction`，并注明 `const` 不参与热重载、必须 Stop + Run |
| `飞书通知与绑定.md:108,136` | `feishu_web_redirect_web.dart`、`feishu_app_launcher.dart`、`feishu_oauth_helper.dart` | 三个文件都已改名/合并为 `oauth_web_history_web.dart`（经 `oauth_web_history.dart` 条件导入）、`oauth_app_launcher.dart`、`oauth_flow_helper.dart`；`MainActivity.kt` 路径补全，channel 名 `com.moe_social/feishu` 核对无误 |
| `飞书通知与绑定.md:172` | 建 Bot 后走 go-zero hook 发飞书通知 | hook 已随 go-zero 删除，替换为 ⚠️ 记录（见 §14.6） |
| `CODE_WIKI.md` | 演示入口 `lib/demo_main.dart` + `home_redesign_demo.dart`；管理台菜单 SSOT `src/config/menu.ts`（`ADMIN_MENU_TREE`） | 两个 demo 文件不存在（`find lib -iname '*demo*'` 为空）；菜单 SSOT 实为 `src/config/workspaceNav.ts` 的 `WORKSPACES`（biz/ai/infra）+ `NAV_BY_WORKSPACE`。同处补注了 `lib/utils/`→`ApiEnvConfig`、`lib/config/`→`AppConfig` 的不同职责 |
| `DESIGN_SYSTEM.md:356` | `lib/theme/moe_theme.dart` | 实为 `lib/theme/moe_theme_extension.dart`（已核对其中的 `class MoeTheme extends ThemeExtension<MoeTheme>` 与 `.light()`/`.dark()`/`lerp`） |
| `API调试指南.md:55-56` | 把 `http://74fd3e66.r3.cpolar.top` 当作「正确的 API 地址格式」示例 | 换成真实的 `http://47.106.175.49:8888`，并补上真正的坑：`_normalizeBaseUrl()`（`api_service.dart:172`）对非法地址返回 `null`，`_applyApiEnvironment()` 拿到 `null` 就**跳过赋值、保留旧值**——写错地址不报异常，只是请求发往一个你没填过的地方。这正是 `config_test.dart` 那条 URL 格式断言存在的理由 |
| `moe-admin-memory-center-design.md:224` | 实现清单里的 `config/menu.ts # 新增菜单项` | `menu.ts` 已于 `2928dd82` 删除（`ADMIN_MENU_TREE` 全仓已无），导航 SSOT 是 `35c6ce87` 引入的 `config/workspaceNav.ts`。这份是**待实现的设计稿**，路径写错会让实现者去找一个不存在的文件 |

顺带核对为**仍然准确、未改动**的：`AdminAuthContext`、`RequireAdmin`、`App.tsx:66` 的 `basename="/ops"`、`moe-admin/src/lib/schemaActions.ts`、`docs/dev/admin-rpc-runtime-guide.md` 里对 `rpcMonitor.ts` 已删的标注。

**刻意保留、不改**：`api_service.dart:420,471` 有两处按 `baseUrl.contains('cpolar.top')` / `ngrok.*` 分支给出隧道专属错误文案。这两个分支今天**必然不进**（基址里已无隧道域名），但它们**自守门**——只有 URL 真含该域名时才触发，所以留着零行为影响、零维护成本；而一旦以后把 `developmentUrl` 指回隧道，正确的提示又会立刻生效。删它属「改动小、收益也为零」，不符合本轮取舍标准。

### 14.5 两个小修

- **`backend/internal/server/routestats/proto_routes_gen.go`**：`protoHTTPRouteCount` 315 → 320。这是生成物，用 `cd backend && go run ./scripts/gen/proto-route-count` 重新生成，未手改。`stats_test.go` 拿它和实际注册路由数比对，漂移会让测试红。
- **`moe-admin/src/lib/rpcMonitor.ts`**：`git rm` 删除。零 import；它是 go-zero RPC 监控面板的数据层，随拆分部署一起退役（`docs/dev/tools/rpc-monitor.html` 已在上一批标注无数据源）。

### 14.6 新发现、本轮未修：飞书「Bot 已创建」通知零调用方

`backend/utils/feishu.go:43` 的 `SendFeishuAgentCreatedNotification()` **全仓零调用方**——go-zero 时代的 hook 被删掉后，没有人在 Kratos 侧把它重新接上。所以「创建 Bot → 飞书通知运营」这个能力**静默不触发**，没有任何报错。

当前真正在跑的飞书链路是 `SendFeishuTestCard`：`internal/biz/user/oauth_feishu.go:136` → `internal/server/protohttp/user/user_login.go:113`。

**未修的理由**：重新接线是功能开发（要决定触发时机、幂等、失败重试、通知内容），不是配置治理，不该夹在这一批里悄悄改。已在 `飞书通知与绑定.md:172` 留 ⚠️ 记录，避免下一个人继续以为它在工作。

同类保留项：`getRuntimeOverview()` 零调用方，但对应后端端点是活的，先留着。

### 14.7 悬空路径扫描：方法与假阳性教训

扫「文档里引用但仓库中不存在的路径」时，第一版检查脚本只尝试 `p` 和 `./p` 两种解析，结果报出 **170 条**「悬空引用」。这个数字是假的：仓库里大量文档路径是**相对 `backend/` 写的**（例如 `internal/biz/...`）。加上 ROOTS 列表（仓库根、`backend/`、`docs/`、`moe-admin/`）与 HISTORICAL 排除列表（明确带「已删除」「历史方案」叙述的段落）后，降到 **22 条可信候选**，其中真正需要改的就是 §14.4 那批。

我没有把 170 这个数字报给用户。**扫描工具的信噪比本身必须先验证**，否则会把一轮清理变成一轮误删。

剩余判定为「目录树片段或显式的已删除叙述」、**不改**的：`backend/docs/dev/kratos-intentional-transport.md` 里的 `transport/oauth.go`/`websocket.go`/`sse.go`/`internal/server/http_transport.go`；`moe-social-runtime.md:83,88` 的 `cmd/dev/main.go`、`api/super.go`、`rpc/super.go`；`private_messages.md:191` 的 `api/internal/types/types.go`；`new-api-kratos.md:62,158` 的 `protohttp/moe_extended.go`、`routestats/proto_routes_gen.go`；`头像框与奖池配置操作流程.md` 的 `assets/frames/star_trail.json`、`lib/gacha_page.dart`。另有 41 处 `api/internal/` 引用多数是合法的历史叙述。`.qoder/repowiki/**` 未跟踪，不处理。

### 14.8 本轮最该记住的教训：`flutter test` 不编译 `lib/main.dart`

回滚 `config.dart` 之后 `flutter test` 报 **99/99 全绿**，但 `flutter analyze` 的问题数从 38 跳到 40：

```
The getter 'envOverride' isn't defined for the type 'ApiEnvConfig' • lib/main.dart:252:37
The getter 'envOverride' isn't defined for the type 'ApiEnvConfig' • lib/main.dart:252:88
```

原因：**测试不会编译 `lib/main.dart`**。没有任何测试 import 它，所以里面写坏了也全绿。凡是动过 `main.dart`，`flutter analyze` 是**强制项**，不能用测试结果代替。已修（启动日志只打 `isProduction`），复验回到 38 issues / 0 error / 99 tests。

同批踩到的另外两个坑，也记在这里：

- **Bash 工具的 cwd 会跨调用保留**。之前一次 `cd backend` 之后，后面的 `grep -rn 'class AppConfig' lib/` 静默返回空——不是「没有」，是「在错误的目录下找」。要么用 Grep 工具，要么显式 `cd` 回项目根。
- **全仓 grep 会被未跟踪的元数据大文件污染**。`grep -rn 'rpcMonitor' .` 把 `.qoder/repowiki/zh/meta/repowiki-metadata.json` 整个（单行巨型 JSON）倒进输出。全仓搜索必须排除 `.qoder/`，或把范围收窄到 `moe-admin/src`、`docs/` 这类真实目标目录。
- **环境里没有 YAML 解析器**（node 无 `yaml`/`js-yaml`，python 无 `yaml`），用 `/usr/bin/ruby -ryaml` 代替；它顺带能以编程方式断言 workflow 的步骤顺序、以及 `dart-define` / `github.event` 插值确实不存在。`node` 也不在 PATH 上，要用 `/opt/homebrew/opt/node@20/bin/node`（v20.20.2）。

### 14.9 验证结果（本轮末次全量复验）

| 检查 | 结果 |
|------|------|
| `cd backend && gofmt -l internal/platform/moewiring/` | 无输出 |
| `go build ./...` · `go vet ./...` | 通过 |
| `go test ./internal/server/routestats/ ./internal/platform/moewiring/...` | ok |
| `flutter analyze` | **38 issues，0 error / 0 warning**（与基线一致） |
| `flutter test` | **99/99 通过** |
| 断言脚本 7 用例（修完 `tr` 折行后重跑） | 全部符合设计，见 §14.1 表；fail-closed 性质成立 |
| `ruby -ryaml` 校验 3 个 workflow | 语法有效；`flutter-release.yml` 10 步，断言=第 7 步、Build APK=第 8 步（顺序正确）；全文件无 `dart-define`；断言 `run` 块内既无 `github.event` 也无 `secrets.` 插值 |
| `moe-admin` `tsc -b` | `src/` 零错误 |

**一处既有失败，与本轮无关**：`moe-avatar/core` 的 `tsc` 报 `src/export.ts(1,19): error TS2307: Cannot find module 'jszip'`。`moe-avatar/core/package.json` 声明了 `jszip ^3.10.1`，但该依赖只装在 `moe-admin/node_modules/` 下，`moe-avatar/core` 自己没装。装依赖超出本轮范围，已标记未修。

**codegraph 无需重生成（已实测）**：跑了一遍 `node scripts/codegraph/gen_all.mjs`，四个 JSON 的内容与 HEAD **逐字节相同**，只有 `generatedAt` 时间戳变化（已还原，避免制造无意义 diff）。原因是 codegraph 是**路由 / 页面 / 服务级**的图，不是符号级的——`rpcMonitor.ts` 删除与 `AppConfig`→`ApiEnvConfig` 改名都落在它的粒度之下（`grep -c 'AppConfig' flutter.json` 本来就是 0）。§13.2 第 8 条那次重生成是必要的（删的是图上的节点），本次不是。

本批（第二批）改动**已提交**为 `3ebcf62d chore: 2026-09-08 配置治理与文档批量修正`（23 文件）；第一批为 `8037287e chore: 清理废弃配置与资源，完成配置治理整改`（80 文件）。**第三批（§15）仍在暂存区未提交**。工作区里还有并行的无关改动（含未跟踪的 `moe_social_backend/`），三批都刻意未触碰。

---

## 15. 2026-09-08 第三批：死配置收敛（批次 4 的一部分）

用户问「死配置能先收掉吗？应该是不影响的吧」。**这个前提一半成立、一半不成立**，先记录不成立的那一半，因为它决定了本批的边界。

### 15.1 前提纠正：`moe.*_api_in_process` **不是死配置**

本文档 §6 早先把它记作「20 个键的信息量等于 1 个键」，暗示可以收敛掉。实测后这个判断要收紧：

| 事实 | 证据 |
|------|------|
| 代码真在读的键有 **20 个**，yaml 里写了 **17 个**（缺 `game` / `notify` / `life`） | `grep -rhoE 'moe\.[a-z_]*api_in_process'` vs `grep -oE '^  [a-z_]*api_in_process' config/config.yaml` |
| 消费点是 **40 处真实装配分支**，形如 `if moewiring.XxxAPIInProcessEnabled() { ctx.XxxApp = … }` | `grep -rn 'APIInProcessEnabled()' --include='*.go' . \| grep -v 'func '` → 40 |
| 缺键的 3 个域**确实在工作**，走 `defaultInProcessEnabled()` 兜底 | 启动冒烟日志第 11 行：`进程内: vip, user, …, game, life, …, notify, community`（22 个域全在） |

所以「收敛为 1 个键」= **重写 40 个调用点**，回归面覆盖全部业务域的装配路径。运行时值虽然恒为 true，但这属于「改动大、收益中」，**不符合本轮「改动小收益大」的取舍标准，未做**。

真正的死配置是下面 15.2 那批——它们的共同特征是**零调用方**，删掉不需要动任何调用点。

### 15.2 已删除（逐项核实过调用方，不是看 grep 命中）

**A. `api.timeout_ms` 整条链**（§6 / §13.2 第 2 条早已登记为「只写不读」）

| 位置 | 动作 |
|------|------|
| `config/config.yaml:31-33` | 删键 + 删警告注释，留一行说明「曾有 timeout_ms，已删；HTTP 超时调 `llm_inference.timeout_seconds`」 |
| `api/etc/moe.yaml:5` | 删 `Timeout: 600000` |
| `internal/platform/apiconfig/config.go:8` | 删 `Timeout int64` 字段 |
| `internal/platform/wiring/config_override.go:67-69` | 删写入块 |
| `pkg/conf/config.go:75-81` | 删 `API.TimeoutMS` 字段与「只写不读」注释（`API` 现在只剩 `PublicBaseURL`） |
| `pkg/conf/conf_test.go:31` | 测试 fixture 同步删键，保持与真实 yaml 镜像 |

零读者的判断依据（重犯 §13.3 那个坑的风险最高，所以逐个确认了接收者类型）：`grep -rn '\.Timeout\b'` 共 16 处命中，其中 `biz/llm/platform_common.go:80,89,98`、`pkg/llminference/{models,stream,client}.go`、`pkg/conf/conf_test.go` 的 `cfg.Timeout` 全是 **`llminference.Config.Timeout`（`time.Duration`）**，与 `apiconfig.Config.Timeout`（`int64`）无关；唯一的写入点就是 `config_override.go:68`。

**B. `moewiring/config.go` 的 Kratos 过渡开关族 —— 15 个函数**

这是 go-zero→Kratos 迁移（当前分支名就是 `feat/kratos-hybrid-migration`）完成后留下的残骸。逐个实测调用方：

| 函数 | 删除依据 |
|------|----------|
| `KratosPureHTTPWithoutLegacy` | 全仓**零引用** |
| `KratosHTTPFrontEnabled` | 零调用方（grep 命中的 `pkg/conf/config.go:241` 是**同名字段**，不是调用） |
| `KratosGRPCManaged` | 同上（`pkg/conf/config.go:242` 是同名字段） |
| `KratosSuperGRPCNative` | 零引用 |
| `SuperGrpcRetired` | 零引用 |
| `KratosHybridHTTPFallback` | 零引用 |
| `PilotProcessDeprecated` | 零引用 |
| `KratosInternalHTTPPort` | 零引用；**连带消灭 `18888` 硬编码兜底**（`pkg/conf/config.go:243` 仍是同名字段，非调用） |
| `KratosPK8GoctlRetired` | 唯一调用方是 `KratosHybridHTTPFallback:152`，而后者本身是死的 |
| `KratosPureEnabled` | **关键**：它的 5 个「调用方」全部在上述死函数内部（`:113,120,127,134,149`），包外零调用 |
| `KratosPilotReadEnabled` | 3 个调用方全在 `config.go` 自己内部（`:63,87,98`） |
| `KratosAdminHTTPEnabled` | 唯一外部调用方是 `wiring/wire_mode.go:14` 的薄封装 |
| `KratosVipHTTPEnabled` | 同上（`wire_mode.go:18`） |
| `KratosAdminInsightsHTTPEnabled` | 同上（`wire_mode.go:10`） |
| `KratosPilotBaseURL` + `KratosAdminBaseURL` | 前者唯一调用方是 `wire_mode.go:6`；后者唯一调用方是前者。**连带消灭 2 处 `19032` 硬编码兜底** |

**C. `wireKratosNotes` 整条链**

- `internal/platform/wiring/wire_mode.go` —— **整个文件删除**（只含上述 4 个薄封装，`git rm`）
- `internal/platform/wiring/wire_platform.go:68-81` —— 删 `wireKratosNotes`，连带删掉因此不再使用的 `fmt` 导入
- `internal/platform/wiring/wire_svc.go:56` —— 删调用

**这条链为什么是零影响**：`wireKratosNotes` 只往启动日志写 note，而它依赖的三个闸全部返回 `false`（`moe.kratos_admin_http_enabled` / `kratos_vip_http_enabled` / `kratos_admin_insights_http_enabled` **在 config.yaml 里根本不存在**，`IsSet` 恒假 → 落到默认值 false）。冒烟启动的 46 行日志里**一条 kratos note 都没有**，实测确认它从来没输出过东西。

顺带修了 `config.yaml:197` 的过期注释：原文「管理台 Moe HTTP 优先走 API 进程内 MoeAdmin（**仍需 RPC 处理发帖/记忆端口**）」——RPC 进程早已整体删除（`backend/rpc/` 不存在），改为「各业务域的 HTTP 装配走进程内 biz（单进程 Kratos HTTP，无 RPC）」。

### 15.3 连带发现：`moeconf` 包现已完全孤立（**已于第五批删除**）

删完上面那批之后浮出一件文档里没预料到的事：

- `moeconf.LoadBootstrap()` 的调用方**只有 4 个，全在被删的死函数里**（`config.go:66,90,101,177`）
- `grep -rln '"backend/internal/platform/moeconf"' --include='*.go'` → **零导入方**
- 包规模：`load.go` 98 行 + `load_test.go` 27 行
- `config.yaml` 的 `moe.kratos_pure_enabled` / `moe.kratos_admin_base_url` 因此也空转了（唯一读者是 `moeconf/load.go:86`）

~~**未删的理由**：删一个包比删函数的影响面大，且 `moeconf` 会牵到 `internal/conf/moe/v1/pilot.pb.go`（protoc 生成物）——那是 §12.5 第 2 步「删 `utils.InitConfig()` 全局单例」的天然组成部分（`LoadBootstrap` 的注释写明它「先 InitConfig，再映射 moe 段」）。**建议并入第 2 步一起做，不要单独删。**~~

> **该建议已于 2026-09-09 第五批被推翻并执行删除**（见 §17.1）。当初三条理由逐条实测后都不成立：
>
> | 当初的理由 | 实测结果 |
> |---|---|
> | 「删一个包比删函数的影响面大」 | 零导入方 ⇒ 零运行时影响；`go build ./...` 与全量测试均通过。影响面大小取决于**反向依赖数**，不取决于它是包还是函数 |
> | 「会牵到 `internal/conf/moe/v1/pilot.pb.go`」 | 牵到，但那条链**整体孤立**：`pilot.proto` 无任何 `import` 者，`pilot.pb.go` 的唯一导入方就是 `moeconf`。所以不是「删不干净」，而是「可以一次删干净」——连同 `scripts/gen/moe-conf.sh` 与 `Makefile` 的 `gen-moe-conf` 目标一起退役 |
> | 「是序 6 删 `InitConfig()` 的天然组成部分，应合并做」 | 合并做的方向反了：删 `moeconf` 让 `InitConfig()` 的**生产调用方从 4 个降到 3 个**，是**推进**序 6，不是与它冲突。等序 6 再做只是让一个已证实孤立的包多活一段时间 |
>
> **教训**：「影响面大所以先别动」在没有反向依赖数据时是一种猜测。§16.2 已经确立「判断收敛进度只能看反向依赖数」，同一条判据反过来也成立——**判断能否删除，也只看反向依赖数**。
>
> 原先加在 `config.yaml` 那两个键上方的 ⚠️ 空转注释，已随键一起在第五批删除。

### 15.4 验证

| 检查 | 结果 |
|------|------|
| `gofmt -l internal/platform/{moewiring,wiring,apiconfig}/ pkg/conf/` | 无输出 |
| `go build ./...` · `go vet ./...` | 通过 |
| `make check` | 通过（`cmd/moe-social` 构建 + `moesocial` / `routestats` 测试） |
| `go test ./...` | **33 包 ok**；唯一 FAIL 是 `pkg/moe/toolaudit` 的既有失败，已确认该包**不依赖**本轮改动的任何包 |
| `ruby -ryaml` 校验 `config.yaml` / `moe.yaml` | 语法有效；`api.timeout_ms` = nil，`moe.yaml` 无 `Timeout` 键 |
| **启动冒烟测试**（`go build -o /tmp/moe-smoke ./cmd/moe-social` 后真实启动 14 秒） | 进程未 panic（`grep -icE 'panic\|fatal'` = 0）；监听 `*:8888` 单端口；日志 `moe-social ready: Kratos HTTP-only on port 8888`；**22 个域全部进程内装配**；bot/dream 两个 scheduler 正常启动 |

冒烟测试是本轮唯一的强验证：wiring 启动路径**没有任何测试覆盖**，`go build` + `go test` 全绿也不能证明装配没被破坏。

> ⚠️ 冒烟启动会**真实写入测试库**（`life_items` / `life_entities` / `life_event_logs` 的 upsert，以及过期 `companion_memories` 的清理）——这是后端正常的启动 seeding 行为。库是测试库（用户已确认开发机直连属预期），`make moe-social` 不带 `-migrate`，日志第 2 行确认 `已跳过 AutoMigrate`，无表结构变更。

**端口硬编码收敛成效**：`18888` 在 Go 代码里从 1 处降到 **0 处可执行命中**（唯一残留是我自己写的说明注释）；`19032` 从 11 处降到 10 处，且**剩余 10 处全部是注释、测试 fixture 或 `.pb.go` 生成物里的注释**，生产代码的可执行兜底路径里已经没有这两个无监听者的端口。

### 15.5 文档一致性收尾 + 顺带查出的一个计数错误

删代码会让审查文档里的行号与结论失效，因此本批同时做了一轮就地更新（不新开章节，避免同一事实两处描述）：

| 被更新的章节 | 更新内容 |
|-------------|---------|
| 文档头「性质」/「有效性」 | 变更记录范围 §13、§14 → **§13–§15**；新增 ⚠️ 行号提醒（`moewiring/config.go` 191 → 80 行，原 `:62-190` 区间引用全部作废） |
| §0 速览表第 4、5、6、7 行 | 第 4 行「Go 硬编码短路」一半已消除、剩驼峰死别名（行号修正为 `config_override.go:73,97`）；第 5 行 Agora 段行号 `moe.yaml:12` → `:11`；第 6 行端口越界标 ✅ 已消除；第 7 行死配置标 ⚠️ 部分完成 |
| §4.2 端口表 | 新增「第三批后状态」列；`19032` 剩余命中性质说明 |
| §5 开头 / §5.1 / §5.2 / §5.3 / §5.4 | 破口计数 5 类 → **剩 2 类**；`moe.yaml` 行号整体上移 1（因删掉第 5 行 `Timeout: 600000`）；§5.3、§5.4 标 ✅ 已消除并保留「原状」描述以便回溯 |
| §6 进度块 + 表 | `api.timeout_ms` → ✅ 已删；`*_api_in_process` 两行按实测重写（40 处调用点 / 三个隐藏开关已验证工作正常）；**新增两行**登记 B、C 两组删除，否则只读 §6 会以为它们还在 |
| §9.1 | 五端口结论补「18888/19032 兜底已删」；末尾「补记」加「再补（第三批后）」说明按原行号已找不到东西 |
| §11 批次 4 / 批次 5 / 批次 6 | 批次 4 标题改为「收敛清单 4 项中 3 项已完成」，收敛清单改为带现状的表格；验收标准如实标注 ⚠️ **当前未达标**（两个空转键）；批次 5、6 的端口条目缩小范围 |
| §12.4 / §12.5 / §13.2 / §13.3 / §13.4 | 第 2 个刻意行为决定标 ❌ 已作废（只剩 1 项需签字）；迁移顺序第 5、6 序范围缩小并绑定 `moeconf` 决定；第 1、2 行处理栏补第三批结果；§13.3 的教训段标注行号已失效 |

**顺带查出的计数错误（已修）**：§12.1 原写「同一份 `config.yaml` 被 **20 处**独立打开：19 个 `viper.New()` + `utils.InitConfig()`」。实测 `grep -rn 'viper.New()' backend/ --include='*.go'` 共 **22** 处，要排除 4 处才得到遗留读取点：

| 排除项 | 处数 | 原因 |
|-------|------|------|
| `deploy/config/config.go` | 2 | 读的是**另一个** `deploy/config.yaml` |
| `pkg/conf/load.go:193` | 1 | **新加载器自己**，不是遗留读取点——原文正是把它误算进去了 |
| `pkg/conf/config.go:3` | 1 | 注释文字命中 |

余 **18** 处遗留 `viper.New()`（分布在 **15** 个文件 —— raw 命中的 16 个文件里要同样排除 `deploy/config/config.go`，口径才与站点数一致，见 §12.1 的文件数修正）+ `utils.InitConfig()` = **19 处**。`backend/pkg/conf/config.go` 的包注释里有同一个 off-by-one，已同步改为 19/18。

第三批**未改变此计数**，已核对 HEAD：被删函数所在的 `moewiring/config.go` 改动前后都只有 1 处 `viper.New()`（在 `moeViper()` 里），被整文件删除的 `wire_mode.go` 是 0 处。

**教训**：`grep` 计数当作结论写进文档时，必须把「新代码自己」和「注释里的字面命中」排除掉——否则文档会拿新加载器当作它要消灭的问题的证据。这与 §13.3 的「命中不等于消费」是同一类错误的计数版本。

---

## 16. 2026-09-09 第四批：第 2 步启动（调用点迁移）

> **基线**：`bec11b26 feat(life, arena): 落地M0/M1a活世界营地预览功能`（2026-09-09 02:31）
> **本批性质**：§12.5 的第 2 步从「未开始」推进到「6 个子步骤完成 1 个」。

### 16.1 已落地：§12.5 序 1（`database.*` → `conf.DSN()`）

| 文件 | 改动 |
|------|------|
| `backend/utils/db.go:96` | 原 `:95-105` 的 11 行内联拼装（8 个 `viper.Get*("database.*")` + `fmt.Sprintf`）→ 1 行 `dsn := conf.DSN()` |
| `backend/utils/db.go:10` | 新增 `"backend/pkg/conf"` 导入 |

**改动前置检查**：
- `database.*` 的真实消费者确认只有 1 处 —— 全仓 `grep -rn '"database\.'` 仅命中 `utils/db.go:97-104`。`internal/platform/appdb/db.go:15` 的 `Open()` 只是转调 `utils.EnsureDB()`，不自建 DSN。
- **无循环依赖** —— `pkg/conf` 的 backend 侧依赖只有 `pkg/llminference`（叶子，零 backend 依赖）；`utils` 依赖 `internal/platform/moelog` + `model`。`go list` 确认 `pkg/conf` 的依赖闭包里没有 `backend/utils`。
- **`ensureConfigLoaded()` 必须保留**（`db.go:83`）—— 见 §16.3，`utils/` 里还有 38 处全局 viper 读取依赖它已装载。本步只换 DSN，不动装载时机。

**验证方式（不是只看编译过）**：临时写了一个等价性测试，同时用**旧路径**（全局 viper + 内联 `fmt.Sprintf`）和**新路径**（`conf.DSN()`）对真实 `config.yaml` 各生成一次 DSN 并逐字节比对，同时比对两侧解析到的配置文件绝对路径。结果：

```
viper 配置文件 = /…/backend/config/config.yaml
conf  配置文件 = /…/backend/config/config.yaml     ← 同一个
旧 DSN = root:****@tcp(47.106.175.49:3306)/go_react_demo?charset=utf8mb4&parseTime=true&loc=Local
新 DSN = root:****@tcp(47.106.175.49:3306)/go_react_demo?charset=utf8mb4&parseTime=true&loc=Local
--- PASS
```

`parseTime=true` 正确出现，即 §12.3 陷阱 1（viper 把 `parseTime` 小写成 `parsetime`，tag 必须写 `mapstructure:"parsetime"`）在真实配置上成立。验证完即删除该临时测试文件，未留在仓内。
口令在输出中脱敏，未落进任何日志或文档。

### 16.2 最重要的发现：`pkg/conf` 此前一整天是死代码

第 1 步（2026-09-08）交付的 `pkg/conf` 共 **1338 行**（`config.go` 259 + `derive.go` 311 + `load.go` 207 + `conf_test.go` 561），`go build ./...` 通过、`go test ./pkg/conf/` 16/16 通过 —— 但直到 2026-09-09 之前，**反向依赖数为 0**：

```bash
go list -f '{{.ImportPath}}|{{join .Imports ","}}|{{join .TestImports ","}}' ./... \
  | awk -F'|' '{ if ($2 ~ /backend\/pkg\/conf/ || $3 ~ /backend\/pkg\/conf/) print $1 }'
# 2026-09-08 → (空)
# 2026-09-09 §16.1 之后 → backend/utils
```

注意 `go list -deps ./... | grep -c 'backend/pkg/conf'` 会返回 **1**，看起来「有人依赖它」——那是 `./...` 把 `pkg/conf` 自己也算进去了。**判断收敛进度只能用反向依赖（谁 import 了它），不能用正向依赖或 grep 命中。**

**教训**：新建统一层 ≠ 收敛完成。「加载器建好了」和「调用点迁过来了」是两件事，中间可以隔着一整天没人发现的死代码，而且全绿。这与 §13.3「命中不等于消费」是同一条纪律的第三种形态：**存在不等于被使用，能编译不等于生效，测试通过不等于接上了。**

### 16.3 §12.5 序 6 的原评估严重低估（已就地更新）

原写「4 个调用者（若同时删 `moeconf` 则降为 3）」。实测：4 是**调用 `InitConfig()` 的地方**，而真正**依赖它已被调用**的是全局 viper 单例的 **50 处读取点 / 16 个文件**（明细见 §12.5 序 6 已更新的单元格）。

按包分：`utils/` 38 处 / 12 文件，`internal/` 12 处 / 4 文件。
按配置段分：`feishu.*` 23、`wechat.*` 8、`private_message.*` 5、`temp_mail.*` 4、`admin.*` 4、`auth.*` 3、`api.*` 1（余 2 处用变量键，如 `wechat_oauth_flow.go:71` 的 `viper.GetString(k)`）。

✅ **类型化侧已完全就绪**：这 50 处共涉及 **32 个唯一键，`pkg/conf` 已全部建模**，含嵌套的 `Admin.Bootstrap.Username/Password`（`config.go:69-72`）。`Config` 顶层 15 个段（`Runtime`/`Auth`/`Admin`/`API`/`Database`/`Image`/`AppClient`/`LLMInference`/`Ollama`/`LocalModels`/`TempMail`/`PrivateMessage`/`Feishu`/`Wechat`/`Moe`）覆盖了当前全部读取需求。**序 6 不缺任何结构体，纯属机械改写。**

> 核对方法上的一个坑：只收集一层 `mapstructure` tag 会把 `admin.bootstrap.username` 误判为「未建模」——它是匿名嵌套结构体，tag 在里层。必须递归展开后再比对。

### 16.4 新登记：`bec11b26` 引入的硬编码运维参数（§4 同类）

`backend/internal/platform/moewiring/api_life.go:8`：

```go
const livingWorldIntervalSeconds = 5 * 60
```

用于 `:24-25` 的 `TickInterval` 与 `FlushInterval`（单位秒，见 `internal/service/life/life.go:16-17`）。提交说明写的是「调整 Life 引擎 Tick/Flush 间隔为 5 分钟，降低服务器空载功耗」——**这是一个运维调优参数，现在被编译进了二进制**，改一次要重新构建 + 部署。

更糟的是它造成了 §4「同一事实的多份副本」：

| 位置 | 值 | 是否生效 |
|------|-----|---------|
| `internal/biz/life/types.go:41` | `TickInterval: 5 * time.Second` | ✗ 被覆盖 |
| `internal/biz/life/types.go:44` | `FlushInterval: 5 * time.Second` | ✗ 被覆盖 |
| `internal/platform/moewiring/api_life.go:8` | `5 * 60` = 300 秒 | ✅ 生效（`life.go:69-73` 仅在 `> 0` 时覆盖） |
| `internal/biz/game/world_runner.go:13` | `defaultWorldTickInterval = 45 * time.Second` | ✅ 生效（`:21` 仅在 `interval <= 0` 时兜底） |
| `config/config.yaml` | 无 `life` / `game` 的 tick 键 | — |

> **补登（2026-09-09 第五批）**：原表只有 3 行，漏了 `world_runner.go:13`。补上后图景更完整也更难看——**同一个「周期 tick」概念在仓里有两套策略**：Life 与 Game 引擎把间隔**编译进二进制**（300 秒 / 45 秒），而 `pkg/moe/runtime/config_load.go:98`（`moe.bot_scheduler_tick_seconds`）与 `pkg/moe/brain/dream_schedule.go:105`（`moe.dream_scheduler_tick_seconds`）的同类调度器**从配置读**。四处硬编码 + 两处可配，没有文档说明为什么两类调度器的可配性不同。

四处表达同一类事实、两处是死值、生效的两处不可配。**建议**：新增 `moe.life_tick_interval_seconds` / `moe.life_flush_interval_seconds` / `moe.game_world_tick_interval_seconds`，由 `pkg/conf` 提供解析方法，`api_life.go`、`world_runner.go` 与 `types.go` 的默认值都改为引用它。此项属批次 5（新配置项接入统一加载器），不阻塞 §12.5。

### 16.5 新登记：`utils/admin_seed.go:32` 的 `admin123` **代码级**兜底

```go
password := viper.GetString("admin.bootstrap.password")
if strings.TrimSpace(password) == "" {
    password = "admin123"
    log.Printf("[admin] 使用默认超管密码 admin123，请尽快在配置中修改 …")
}
```

§3 的 P0 表已登记 `config.yaml:28` 的明文 `admin123`，但**那是配置文件里的值，这一条是代码里的兜底**，性质不同：

- 触发条件是 `admin.bootstrap.password` **缺失或为空**，且仅在超管表为空时（`admin_seed.go:23` `if count > 0 { return }`）
- **凭据轮换修不掉它** —— 把 `config.yaml` 去跟踪、换成新密钥之后，只要新环境忘了配 `bootstrap.password`，代码就会静默种下 `admin123` 超级管理员
- 它只打一行日志，不阻断启动

**建议**：改为缺失即启动失败（或拒绝种账号并要求显式初始化），与 P0-1 的 gradle `?: "moe123456"` 是同一处置原则 —— **口令类配置不允许有兜底默认值**。此项与 §12.6 的拆分**互相独立**，可以先做。

### 16.6 核实后确认「不是问题」的两项

为避免把怀疑当结论写进文档，以下两项已查证并排除：

| 一度怀疑 | 核实结果 |
|---|---|
| `pkg/conf/conf_test.go:178` 断言 `Admin.Bootstrap.Password != "admin123"`，是否把真实凭据烤进了测试、轮换后会红 | **不是。** `loadFixture()`（`conf_test.go:148-161`）把**合成 fixture** 写进 `t.TempDir()` 再 `LoadFile`，`admin123` 是 fixture 数据，与真实 `config.yaml` 无关 |
| `TestRealConfigYAMLLoads`（`conf_test.go:508`）读真实 `config.yaml`，是否断言了凭据值 | **不是。** 它只断言**结构性非空**：`Runtime.HTTPPort > 0`、`Database.DBName != ""`、`Database.Host != ""`、`Database.ParseTime == true`、`Path() != ""`。**凭据轮换后仍然通过** —— 这个设计是对的，可作为 §12.6 拆分后冒烟用例的范本 |

### 16.7 验证

| 检查 | 结果 |
|------|------|
| `go build ./...` | ✅ 通过 |
| `go vet ./utils/ ./pkg/conf/` | ✅ 通过 |
| `gofmt -l utils/db.go` | ✅ 无输出 |
| `go test ./utils/ ./pkg/conf/` | ✅ 均 `ok` |
| DSN 新旧等价性（真实 config.yaml） | ✅ 逐字节相同，见 §16.1 |
| `go test ./...` 全量 | ⚠️ 仅 1 个失败：`pkg/moe/toolaudit` 的 `TestBuildSchemaItemsCoversAllTools`（`expected >=6 tools, got 5`）。**已确认为既有失败且与本批无关**：`go list -deps ./pkg/moe/toolaudit` 不含 `backend/utils` 也不含 `backend/pkg/conf`；把 `utils/db.go` 的改动 `git stash` 之后该测试**同样失败** |
| `pkg/conf` 反向依赖 | ✅ 从 0 → 1（`backend/utils`） |
| 遗留 `viper.New()` | 20 处（含 `deploy/config/config.go` 的 2 处）→ 口径对齐后仍为 **18 处 / 15 文件**。本批**未减少**该计数：序 1 消除的是 `viper.Get*` 读取，不是 `viper.New()` 实例；`utils/db.go` 本来就不在 18 处之内（它走全局单例） |

---

## 17. 2026-09-09 第五批：冗余收拢（纯删除，零行为变化）

> 需求方问「是否有些冗余的功能可以进行收拢」，本批是对该问题的第一轮回答。
> **四项全是删除，没有一项改变运行时行为**：每一项的依据都是「反向依赖数为 0」或「读取目标恒不存在」，不是「看起来没用」。
> 顺序上刻意排在 §12.5 序 3–6 之前：**先删再迁**，否则同一批文件要改两遍。

### 17.1 已删除：`moeconf` 整包 + 孤立的 `internal/conf` 生成链

| 删除物 | 规模 | 依据 |
|---|---|---|
| `internal/platform/moeconf/{load.go,load_test.go}` | 125 行 | 零导入方（§15.3 已实测，本批复测仍为 0） |
| `internal/conf/moe/v1/{pilot.proto,pilot.pb.go}` | 563 行 | `pilot.proto` 无任何 `import` 者；`pilot.pb.go` 唯一导入方就是 `moeconf` |
| `internal/conf/README.md` | 14 行 | 只描述上面那个包 |
| `scripts/gen/moe-conf.sh` | 26 行 | 只生成上面那个包 |
| `Makefile` 的 `gen-moe-conf` 目标 | 3 处（`.PHONY` / `gen:` 依赖 / 目标体） | 同上。`make -n gen` 实测从 3 步降为 2 步 |
| `config.yaml` 的 `moe.kratos_pure_enabled` / `moe.kratos_admin_base_url` | 2 键 + 3 行 ⚠️ 注释 | 唯一读者是 `moeconf/load.go:86,80` |

连带修改：`backend/scripts/README.md`（活跃脚本清单）、`backend/docs/dev/kratos-intentional-transport.md`（`make gen` 链路图 + 「已退役」表补一行）、`internal/platform/moewiring/config.go:78-82`（原注释指向已删文件）。

**§15.3 那条「不要单独删」的建议被推翻**，三条理由的逐条实测见 §15.3 内的表格。

### 17.2 已删除：`pkg/conf` 里生下来就没有调用方的 `Kratos*` 层

这是本批最值得注意的是**位置**：死代码长在**新建的 SSOT 内部**。

| 删除物 | 位置 | 实测依据 |
|---|---|---|
| 4 个导出方法 `KratosAdminHTTPEnabled` / `KratosVipHTTPEnabled` / `KratosAdminInsightsHTTPEnabled` / `KratosAdminBaseURL` | `derive.go:231-258` | `conf.Xxx()` 形式的外部调用方**均为 0**；它们在 `moewiring` 的迁移目标已于第三批删除（`moewiring/config.go:66-69` 记录了那 15 个开关） |
| 9 个类型化字段 `KratosPureEnabled` … `KratosPilotReadEnabled` | `config.go:233-241` | 零外部读取方。其中 **7 个对应的键在 `config.yaml` 里根本不存在**（实测该文件只有 `kratos_pure_enabled` / `kratos_admin_base_url` 两个 `kratos_*` 键） |
| `MoePilot` 类型 + `Config.Moe.Pilot` 字段 | `config.go:224,244-250` | 唯一消费者是 `moeconf` 的 Bootstrap 映射；且 `moe.pilot` 段在 `config.yaml` 里**从来不存在**（`grep pilot config/config.yaml` exit 1），4 个字段一直读零值 |
| 专属用例 `TestKratosGates` | `conf_test.go:419-438` | 断言的是上面 4 个已删函数。**这是「用测试把死代码保住」的实例**，详见 §12.4 的澄清 |
| fixture 里的 `kratos_pure_enabled` / `kratos_admin_base_url` / `pilot:` 段 | `conf_test.go:136-142` | 对应字段已删 |

`viper.Unmarshal` 未设 `ErrorUnused`（实测 `pkg/conf/load.go:199` 只有裸 `Unmarshal`），所以删字段不会因 YAML 里残留键而报错——这也意味着**删字段是安全的，但反过来「字段存在」不能证明「键存在」**。

### 17.3 已删除：15 处恒零值的 `ollama.*` 回退

分布是**同一段 5 键回退链被逐字复制三遍**：

| 文件 | 处数 |
|---|---|
| `internal/adapter/moeconfig/inference.go:25-52` | 5 |
| `internal/platform/wiring/config_override.go:29-57` | 5 |
| `pkg/moe/runtime/config_load.go:24-46` | 5 |

5 个键：`ollama.base_url` / `api_style` / `api_key` / `memory_model` / `timeout_seconds`。

**两层证据说明它们恒为零值**：

1. `config.yaml:122-125` 的 `ollama:` 段**整段被注释掉**。
2. 更强的一层：那个被注释的段**只定义过 2 个键**（`base_url`、`timeout_seconds`）。所以 `ollama.api_style` / `api_key` / `memory_model` 这 **9 处读取的目标键，在配置文件的任何历史版本里都不存在过**——它们不是「曾经能用的回退」，是抄的时候顺手编出来的。

删除后 `grep -rn '"ollama\.' --include='*.go'` 全仓归零。`llm_inference.*` 主路径与 `MOE_LLM_*` 环境变量优先级完全不变。

### 17.4 已删除：`config_override.go` 的驼峰死别名（比 §12.1 记录的多）

§12.1 只举了一处（`image.local_dir` 三键并查）。实测**同一模式共 11 处 `image.*` 调用 + 1 处不可达 else-if**：

- 3 处三键并查：`image.local_dir` / `image.public_base_url` / `image.max_bytes`，第 2、3 个参数分别是无下划线变体与驼峰变体
- 8 处两键并查：`image.driver` 与 `image.oss.{endpoint,bucket,access_key_id,access_key_secret,prefix,public_base_url,region}`，第二个参数是驼峰变体
- 1 处不可达分支：`v.IsSet("image.oss.proxy_via_api")` 的 `else if v.IsSet("Image.OSS.ProxyViaAPI")`

**为什么全是死的**：viper 把查找键整体小写化，所以 `"Image.OSS.Endpoint"` 与 `"image.oss.endpoint"` 是**同一个键**——两键并查等于把同一个键查两遍。而无下划线变体（`image.localdir` 等）与驼峰变体在任何 YAML 里都不存在：`config.yaml` 的 `image:` 段全是 snake_case（`:152-166` 实测），驼峰写法属于**另一个文件** `api/etc/moe.yaml:34-35`（`Image:` / `LocalDir:`），那个文件走 `yaml.Unmarshal` 进 `apiconfig.Config`，**不经 viper**。本函数的 `v` 只 `SetConfigName("config")`，永远加载不到它。

折叠为单键直读后，`firstNonEmptyString` / `firstPositiveInt64` 两个辅助函数再无多键调用方，整体删除（文件 141 → 111 行）。

### 17.5 本批的判据：只删「永远不会再被调用」的，保留「等待迁移」的

删除过程中遇到一个真实的判断点，值得记下来因为它会反复出现：

`derive.go:126 HTTPPort()` 的**唯一调用方**就是零调用方的 `KratosAdminBaseURL()`。删掉后者，前者就变成零调用方——按「反向依赖为 0 就删」的机械判据，它也该删。

**但它不该删。** 区别在于：

| | `Kratos*` 那 4 个方法 | `HTTPPort()` |
|---|---|---|
| 迁移目标 | 已在第三批**被删除** | §12.5 序 2 **尚未开始** |
| 未来是否会有调用方 | 永远不会 | 会（`runtime.*` 迁移时） |
| 处置 | 删 | 保留 |

**判据**：`pkg/conf` 现在是一个**只建了一半的 SSOT**，它的导出函数里有两类零调用方——「目标已消失」的和「目标还没来」的。二者在 `grep` 上完全无法区分，只能靠**去查它对应的那条迁移路线是否还存在**来区分。§12.5 的表就是这份判据的来源。

同理保留的还有 `MoeProduction`（`derive.go:130` 在读 `ExternalHTTPPort`，且 `startupconfig.go:73` 仍读同一个 YAML 键）与 `Inference()` / `GameInference()` 等。

### 17.6 新发现（本批未修，已记账）

| # | 发现 | 证据 | 影响 |
|---|---|---|---|
| a | **`make check` 既不跑 `gofmt` 也不跑 `go vet`** | `Makefile` 的 `check:` 只有 `go build -o /dev/null ./cmd/moe-social` + `go test ./internal/platform/moesocial/... ./internal/server/routestats/...` | 实测 `gofmt -l` 命中 **92 个文件**（如 `utils/retry.go` 的 struct 字段对齐）。**这是既有状态，与本批无关**——本批改动的 7 个文件 `gofmt -l` 全部为空。但它意味着文档里历次「`make check` 通过」的**证据强度被高估了**：它验证的范围比名字暗示的小得多 |
| b | **`pkg/moe/toolaudit` 失败根因确定：测试阈值过期于产品决定** | `record_test.go:11` 硬编码 `len(items) < 6` 即 fatal；`pkg/moe/tools/registry.go` 实测只有 **5** 个 `Name:`；最后一次改动是 `14edac0e`「移除了一些不需要的能力」 | 不是回归，是**测试没跟上主动删能力的决定**。该包只依赖 `backend/pkg/moe/core`，与本批及第四批均无关（§16.7 已用两种方式证明过既有性）。处置需产品侧确认阈值该是几 |
| c | **`apiconfig.Config.Image` 用 `json`/`yaml` 驼峰 tag，是序 3 的迁移陷阱** | `internal/platform/apiconfig/*.go:55-72`：`LocalDir string \`json:"LocalDir" yaml:"LocalDir"\`` 等 | viper 的 `Unmarshal` **只认 `mapstructure`**。序 2/序 3 若图省事把 `apiconfig.Config` 直接喂给 viper，所有字段会**静默落空**——正是 §12.1 的「静默取零值」。迁移时必须逐字段显式赋值，或给 `apiconfig` 补 `mapstructure` tag |
| d | 仓库里有一个**二进制产物** `backend/bin/moe-social` | `grep -rn moeconf` 时命中 `Binary file backend/bin/moe-social matches` | 仓库卫生问题（§11 批次 6 范围）。二进制里还留着已删包的字符串，会让基于 grep 的审计出现幽灵命中 |
| e | **第三梯队冗余：已记账，本批刻意不动** | `moesocial/run.go:19-21` 是单行透传（`Run` → `runHTTPOnly`），`pure` / `http_only` 等限定词在单进程化后不再区分任何东西；`firstNonEmpty` 有 **6 份语义等价实现**（其中 3 份逐字节相同）+ 2 个变体；两个 `main` 重复 3 个 flag 声明 | 均为**低价值或有反效果**：为 6 行私有纯函数新建 `pkg/strutil` 属于过度抽象，代价是新增一层跨层依赖；启动链改名会碰两个入口。判断是「记账不动手」，不是「没看见」 |

### 17.7 验证

| 检查 | 结果 |
|------|------|
| `go build ./...` | ✅ 通过 |
| `go vet ./...` | ✅ 无输出 |
| `gofmt -l`（本批改动的 7 个文件） | ✅ 全部为空 |
| `go test ./...` 全量 | ⚠️ 仅 1 个失败：`pkg/moe/toolaudit`，根因见 §17.6 b，与本批无关（该包只依赖 `pkg/moe/core`，不引用本批任何改动文件） |
| `go test ./pkg/conf/ ./internal/platform/...` | ✅ 全部 `ok` |
| `make -n gen` | ✅ 从 3 步降为 2 步（`moe-proto.sh` + `proto-route-count`） |
| 残留 `"ollama.` 读取点 | ✅ 15 → **0** |
| 残留 `firstNonEmptyString` | ✅ → **0** |
| 残留 `moeconf`（精确匹配，排除同名的活包 `moeconfig`） | ✅ 21 → **2**，且两处都是**有意保留的历史注释**（`moewiring/config.go:78`、`pkg/conf/config.go:27`） |
| 遗留 `viper.New()` | 18 处 / 15 文件 → **17 处 / 14 文件**（见 §12.1 第五批计数） |
| `utils.InitConfig()` 生产调用方 | 4 → **3** |
| `pkg/conf` 反向依赖 | 1（`backend/utils`），**本批未增加**——纯删除不产生新接线 |

> ⚠️ **本批自己踩到的口径陷阱**：用 `grep -rn 'moeconf'` 做残留检查会得到 **18 处**，看起来像没删干净。实际其中 16 处是 **`moeconfig`**（`internal/adapter/moeconfig`，一个活包，被 `bootstrap/scheduler.go` 与 `moewiring/api_*.go` 共 5 个文件使用）——`moeconf` 只是它的**子串**。必须用 `grep -rnE 'moeconf([^i]|$)'` 才是真口径。**这与 §15.5、§12.1 的分子分母错误、§13.3 的命中≠消费是同一族错误：grep 的字面命中不等于要问的那个东西。**

---

## 18. 进度计量口径（2026-09-09 建立，后续各批统一用这个）

本文档此前多次出现「完成度」表述，但从来没有定义过分子分母，导致 §12.5 的「5」「4 个调用者」连续三次低估。本节把口径钉死，**以后报百分比只准用这一套**。

### 18.1 唯一分母：配置键引用（口径 F）

> **一个「键引用」= Go 源码里一个形如 `"<段>.<子键>"` 的字符串字面量**，不论它被传给哪种查找形式。
> 排除：`_test.go`、`pkg/conf/`（SSOT 自己）、`deploy/`（读的是另一个 `deploy/config.yaml`）、`api/`（生成的 proto —— 里面 `"admin.v1.AdminApp"` `"moe.v1.MoeAdmin"` 是 **gRPC 服务名**，会被段名正则误命中，实测 3 处）。

**为什么必须按「键字面量」而不是按「行」或按「`v.Get*(` 出现次数」计**：实测仓内存在**六种**读取形式，任何按调用形态枚举的口径都会漏。

| # | 形式 | 例子 | 位置 |
|---|------|------|------|
| ① | 全局单例直读 | `viper.GetString("feishu.app_id")` | `utils/feishu.go` 等 16 文件 |
| ② | 局部实例直读 | `v.GetString("llm_inference.base_url")` | `moeconfig/inference.go` 等 |
| ③ | 辅助函数（`v` 作首参，变参键） | `firstNonEmptyString(v, "image.local_dir", …)` | `config_override.go`（第五批已删） |
| ④ | 辅助函数（`v` 由内部取，键在 slice 里） | `boolOr(moeViper(), []string{"moe.api_in_process"}, false)` | `moewiring/config.go:28,45,50,55` |
| ⑤ | 变参键列表（内部用全局单例） | `firstNonEmptyConfig("wechat.app.app_id", …)` | `utils/wechat_oauth_flow.go:69` |
| ⑥ | 辅助函数（`v` + 变参键，另一份实现） | `firstViperString(v, "image.max_bytes", "Image.MaxBytes")` | `utils/admin_runtime_config.go:121,130` |

> ⚠️ **建立本节口径时我自己连续漏了三次，过程记下来防复发**：
> 第一版只数 ①② → 得到「172 处」；发现 `config_override.go` 在第五批后**从 22 涨到 26**（看起来变差），追出 ③ → 修正为「185 处」，并以为口径已经稳了。
> 直到把唯一键清单打出来，发现 **`moe.api_in_process` / `moe.single_process` 凭空消失** —— 而这两个是 §12.3 陷阱 2 明确认定的**活**开关，不可能消失。追下去才找到 ④：它们藏在 `boolOr(moeViper(), []string{…})` 里，**19 个 `moe.<domain>_api_in_process` 域开关对前两版口径全部不可见**。再往下又翻出 ⑤⑥。
> 三版分母：172 → 185 → **254**，差了 48%。
> **教训：口径要按「数据形态」（键字面量）定义，不要按「调用形态」枚举。按形态枚举的口径，每多一个辅助函数就漏一批，而且漏掉的往往正是被封装得最好的那部分代码。**

### 18.2 两个百分比：消除率 vs 有效收敛率

需求方 2026-09-09 指定：**按「整体有效的提升」核算**。所以本节给两个数，且**只有第二个算成绩**。

| 指标 | 基线（第五批开工前 HEAD） | 第五批后 | **第六批后（批6a + 序6）** | 累计变化 |
|------|------|------|------|------|
| 键引用出现次数 | 254 | 192 | **116** | −138（−54.3%） |
| 唯一键数 | 155 | 118 | **65** | −90（−58.1%） |
| 涉及文件数 | 48 | 46 | **31** | −17 |
| 遗留 `viper.New()` 站点 | 20 处 / 16 文件 | 19 处 / 15 文件 | **19 处 / 15 文件** | −1（§17.1 删 `moeconf`） |
| `utils.InitConfig()` 生产调用方 | 4 | 3 | **0（函数已删）** | −4 |
| `pkg/conf` 反向依赖（导入方文件数） | 0 | 1 | **17** | +17 |
| **有效收敛率（定义见下）** | 0 / 105 | 8 / 105 | **41 / 105** | **39.0%** |

> 「遗留 `viper.New()`」一行此前记作 18/15 → 17/14，与附录 A 的命令口径不一致（差 2 处）。本表统一为**排除 `_test.go` 与 `pkg/conf/` 自身**后的实测值，复核命令见附录 A。
> **当前 HEAD 就是第五批开工前的 HEAD**（第五、六批全部未提交），已用口径 F 实测核对：HEAD 同为 254 出现次数 / 155 唯一键，故基线列无需重算。

> **有效收敛率 = 已改由 `pkg/conf` 读取的唯一键 ÷ 真实需要收敛的唯一键。**
> **删除死代码记 0 分** —— 它缩小的是噪音，不是把任何一处配置变得更可管理。这条定义直接把「删掉 40 处死代码」从成绩里剔除了，也正是 §18.2 上面那张表里 54.3% 与 39.0% 差距的全部来源。
> **一个键只有在其非 `pkg/conf` 读者归零时才算收敛。** 按这条判定，序 6 覆盖的 38 个键里只有 33 个真收敛 —— 剩下 5 个（`auth.access_secret` `auth.access_expire_seconds` `admin.jwt_secret` `admin.token_expire_hours` `api.public_base_url`）在 `config_override.go` / `admin_runtime_config.go` / `cmd/temp-mail-password` 里还有读者，那些属序 2，详见 §19.3。

**分母 105 的来历**（基线 155 唯一键 − 50 个死键；第六批后再次交叉验证：现存 65 唯一键里有 1 个 `wechat.enabled` 已收敛但仍以字面量形式存在于 `conf.IsSet()` 调用中，故未收敛 = 64，64 + 41 = **105** ✅）：

| 死键类别 | 键数 | 状态 |
|---------|-----|------|
| `ollama.*`（config.yaml 无此段，回退恒零值） | 5 | ✅ 已删（§17.3） |
| `moe.kratos_*` | 8 | ✅ 已删（§15.2 / §17.2） |
| `moe.pilot.*`（config.yaml 从来不存在） | 4 | ✅ 已删（§17.1） |
| `moe.production.{internal_grpc_port,pilot_grpc_port,pilot_http_port,unified_entry}` | 4 | ✅ 已删（§17.1） |
| `moe.{use,register}_{moe,v1}_grpc` | 4 | ✅ 已删（§17.1）——**本节新登记**：config.yaml 0 命中，唯一读者是 `moeconf/load.go:76-77`，即「死键被死代码读」 |
| `image.{localdir,maxbytes,publicbaseurl}` + `Image.OSS.ProxyViaAPI` | 4 | ✅ 已删（§17.4） |
| `Image.*` 驼峰别名（`api_post.go` 10 + `admin_runtime_config.go` 3，去重 11） | 11 | ✅ **已删（§19.1 批6a）** |
| `wechat.*` 历史拼写（20 键里只有 10 键在 config.yaml 存在） | 10 | ✅ **已删（§19.2 序6，随 `wechatFlowCredentials` 一并消失）** |
| 合计 | **50** | **全部已删** |

> ⚠️ **§17.4 的「已删完」是错的，此处更正（已于 §19.1 批6a 修复）**：那一批只清了 `config_override.go`。同一类驼峰死别名当时在**另外两个文件**里还活着 —— `internal/platform/moewiring/api_post.go:18-28`（10 处）与 `utils/admin_runtime_config.go:79-81`（3 处）。
> 更讽刺的是 `api_post.go:64` 自己的注释就写着「驼峰别名同样命中不了（viper 会把键小写）」，而它上面 46 行正在用 10 个驼峰别名。
> 这 10 处又分两种死法：`Image.Driver`/`Image.OSS.Endpoint`/`Bucket`/`Prefix`/`Region` 小写化后**与第一个参数是同一个键**（`firstNonEmpty` 里查两遍同一个键）；`Image.LocalDir`/`PublicBaseUrl`/`MaxBytes`/`OSS.AccessKeyID`/`AccessKeySecret`/`OSS.PublicBaseUrl` 小写化后是 `image.localdir` 之类**在任何 YAML 里都不存在的键**（`api/etc/moe.yaml:37` 的 `MaxBytes` 走 `yaml.Unmarshal`，不经这个 viper，见 §17.4）。

### 18.3 到 50% 有效的路径（2026-09-09 序2 完成后重算）

**50% = 53 / 105。** 序2 已落地，实测 **63 / 105 = 60.0%**，比本节上一版预测的 62（59.0%）多 1 键，多出的那键见下方更正。各块键数按实测唯一键计、已扣除死键：

| 块 | 覆盖的段 | 真实唯一键 | 累计 | **有效收敛率** | 状态 |
|----|---------|-----------|------|--------------|------|
| **已完成** | 序1 `database.*` 8 + 序6 实收 33（`feishu` 12 · `wechat` 10 · `private_message` 5 · `temp_mail` 4 · `admin` 2）+ 序2 实收 22（`image.*` 12 · `runtime.*` 3 · `auth.*` 2 · `admin.*` 2 · `app_client.*` 1 · `api.*` 1 · **`moe.production.external_http_port` 1**） | **63** | 63 | **60.0%** | ✅ 已跨过 50% |
| 序 3 | `llm_inference.*` 10 · `local_models.*` 2 | +12 | 75 | 71.4% | ❌ 待签字 §12.4 |
| 序 4 / 序 5 | `moe.*` **30**（19 个 `*_api_in_process` + 3 个全局闸 + 8 个调度器/模型） | +30 | 105 | 100% | ❌ |

> **记账更正（第三版）：序2 实收 22 键，不是预测的 21。**
> 差的 1 键是 **`moe.production.external_http_port`** —— 它按段名属于 `moe.*`，上一版整块划给序4/序5；但它唯一的非 `pkg/conf` 读者是 `moesocial/startupconfig.go:73` 的 `v.GetString(...)`，被序2 的增量 2f 一并换成 `conf.HTTPPort()` 后就归零了，按 §18.2 的判定规则只能记在序2 名下。所以序4/序5 的 `moe.*` 从 31 缩到 **30**，总数仍是 105（41 + 22 + 12 + 30 = 105 ✅）。
> `runtime.*` 记 3 不是 4：config.yaml 里有 4 个 `runtime` 叶子键，但 `runtime.http_host` 从来没有出现在 `pkg/conf` 之外的字面量里（`moesocial/run.go:38-52` 的 `apiListenAddr` 读的是 **API 片段**的 `Host`，不是这个键），因此它不在 §19.3 那份 64 键的普查里，两头都不计。

> **上一版最重要的结论已被证实：过 50% 确实只需要序 2 一步，且不需要签字。** 序6 → 39.0%，序2 → **60.0%**。上一版的「累计 62」也算对了，只是拆分从「序2 21」变成「序2 22」。

> ✅ **§18.3 上一版登记的三个障碍，处置结果：**
> 1. ~~`admin_runtime_config.go` 是「读—改—写」路径，`pkg/conf` 没有 setter~~ → **读路径已迁**（`ReadRuntimeConfig` 改用 `conf.Reload()`），**写路径按预判保留 viper**（`v.Set()` ×5 + `v.WriteConfig()`）。这 5 个 `v.Set` 字面量是口径 F 里仅剩的**写路径**命中，不是读者，见 §20.2。
> 2. ~~`conf.Reload()` 零调用方 → 管理台写回后缓存陈旧~~ → **已修**，`Reload()` 现有 1 个调用方（`admin_runtime_config.go:76`），且写回后追加了 `conf.LoadFile(path)`（`:119`）让缓存指向刚写的文件。这是序2 唯一的真风险点，已用往返探针验证，见 §20.4。
> 3. ~~`image.oss.access_key_id/secret` 会新增环境变量兜底~~ → **未发生**。实测真实消费方 `biz/media/store_oss.go:29-34` 已经做了「文件优先、`MOE_OSS_*` 兜底」，本层再兜一遍是重复的，所以改为只取文件值（`config_override.go`），行为零变化。这条障碍是我上一版**评估过头**了。

> ✅ 上一版另一条预判成立：`config_override.go` 的 `MOE_AUTH_ACCESS_SECRET` → `auth.access_secret` 层叠与 `conf.AuthAccessSecret()` 逐字同义，直接替换即可。
> ⚠️ 序3 会撞上 §17.6(c) 那个 tag 陷阱，而它**已经是一个活 bug**，实测证据见 §19.4（登记为待办 #27，修法与签字无关）。

---

## 19. 2026-09-09 第六批：批6a 死别名清理 + 序6 全局单例迁移

本批两步：批6a 是序6 的前置清理（先把「同一个键查两遍」的噪音删掉，序6 的迁移面才干净），序6 是本文档到目前为止**唯一一次真正拆掉全局 viper 单例**的改动，也是有效收敛率从 7.6% 跳到 39.0% 的那一步。

### 19.1 批6a：删掉最后 11 处驼峰死别名

§17.4 当时宣布「驼峰死别名已删完」是错的（已在 §18.2 就地更正）。实测还剩两个文件：

| 文件 | 处数 | 处置 |
|------|-----|------|
| `internal/platform/moewiring/api_post.go:18-28` | 10 | 删掉 `firstNonEmpty` 里的驼峰第二参数 |
| `utils/admin_runtime_config.go:79-81` | 3 | 连同 `firstViperString` / `firstViperInt64` 两个**零调用方**辅助函数一起删 |

去重后 11 个唯一键，两种死法见 §18.2 的更正块。

> **口径 F 的副作用收益**：`admin_runtime_config.go` 那两个辅助函数删掉后，§18.1 表格里的读取形式 **⑥ 从此在仓内不存在**，六种读取形式降到四种。口径 F 按数据形态定义，所以这个变化不影响计量，但确实让后续批次更难再漏。

**批6a 实测**：出现次数 192 → 179，唯一键 118 → 107，驼峰别名归零。**按 §18.2 的定义本步记 0 分** —— 删的是死代码，没有任何一处配置因此变得更可管理。

### 19.2 序6：50 处全局单例读取 → `pkg/conf`，并删掉 `utils.InitConfig()`

迁移面 16 个文件、50 处读取，逐文件记录：

| 文件 | 处数 | 收敛方式 |
|------|-----|---------|
| `utils/feishu.go` | 6 | `fs := conf.Get().Feishu` 单次快照 → `.Enabled/.ReceiveID/.ReceiveIDType/.AppID/.AppSecret` |
| `utils/feishu_oauth.go` | 6 | 同上 + `conf.FeishuRedirectURI()`；**顺带删掉零调用方的 `FeishuOAuthRedirectURI()`** |
| `utils/wechat_oauth.go` | 5 | `conf.Get().Wechat` 快照 + `conf.WechatFlowCredential(flow)` + `conf.WechatRedirectURI()` |
| `utils/private_message.go` | 5 | `conf.Get().PrivateMessage` 快照；90/30 硬编码兜底**原样保留** |
| `internal/service/user/user_temp_mail.go` | 5 | `conf.Get().TempMail` 快照；口令种子处**故意偏离**，见下 |
| `utils/feishu_contact.go` | 4 | `fs := conf.Get().Feishu` → `.AutoAddToDirectory/.DefaultDepartmentID/.AppID/.AppSecret` |
| `internal/biz/user/oauth_wechat.go` | 4 | `conf.Get().Wechat.Enabled` + **`conf.IsSet("wechat.enabled")` 必须保留**，见下 |
| `utils/feishu_public_config.go` | 3 | `fs := conf.Get().Feishu` → `.EnterpriseNotice/.Enabled/.EnterpriseInviteURL` |
| `utils/admin_seed.go` | 2 | `conf.Get().Admin.Bootstrap`；`admin123` 兜底**故意保留**（那是未授权的 #18） |
| `utils/auth_jwt_config.go` | 2 | **死代码删除**，非迁移，见下 |
| `utils/admin_jwt.go` | 2 | **死代码删除**，非迁移，见下 |
| `internal/biz/user/oauth_feishu.go` | 2 | `conf.Get().Feishu.Enabled` ×2 |
| `utils/feishu_oauth_redirect.go` | 1 | `conf.Get().Feishu.AppReturnURL` |
| `utils/wechat_oauth_redirect.go` | 1 | `conf.Get().Wechat.AppReturnURL` |
| `internal/biz/ai/provider_keys.go` | 1 | `conf.AuthAccessSecret()`（该文件唯一的 `utils.` 用途，导入随之换掉） |
| `internal/biz/admin/dashboard.go` | 1 | `conf.Get().Feishu.Enabled` |

**`utils.InitConfig()` 已删除。** 删前先跑了一道决定性安全闸：枚举全仓所有包级 `viper.X(` 直读，确认删掉单例后不会留下「孤儿读者静默拿零值」。结果（同口径对照 HEAD）：

| | HEAD | 序6 后 |
|---|---|---|
| 全局单例直读 `viper.GetString/GetBool/IsSet/...(` | **64 处** | **0 处** |

> ⚠️ **两个入口点必须换成 `conf.Load()` 并传出 error，不能直接删调用。**
> `InitConfig()`（原 `utils/db.go:40-56`）实测只有 `SetConfigName` + `SetConfigType` + 3× `AddConfigPath` + `ReadInConfig`，**没有 `AutomaticEnv()`、没有 `SetDefault()`** —— 所以逐键替换不改变环境变量与默认值语义，这是序6 能当机械活做的前提。
> 但它**返回 error**，是响亮的启动失败；而 `conf.Get()` 读不到文件时**静默返回零值 Config**（`load.go:44-45` 注释明说）。因此 `moesocial/run_http_only.go:18` 与 `cmd/migrate/main.go:28` 都改成了 `if _, err := conf.Load(); err != nil { … }`。否则「配置读不到」会从启动失败退化成全零值静默运行 —— 正是 §5.5 那类 bug 的放大版。`load.go` 的 `searchDirs`（`:14`）与被删的 3 个 `AddConfigPath` **顺序完全一致**，故路径解析可证等价。

> ✅ **对 §18.3 原计划的一处偏离，且是更好的做法**：原文要求 `utils/db.go:32-37` 的 `ensureConfigLoaded()` 把 `viper.ConfigFileUsed() != ""` 哨兵换成 `conf.Err()` / `conf.Path()` 判定。实际改成了 `_, err := conf.Load(); return err`。理由：`Err()` 只**报告**上次失败、不重试，而 `Load()`（`load.go:76`）在一次失败的 `Get()` 之后**总会重试并返回错误**；这个返回值正是阻止 `conf.DSN()` 静默拼出一条垃圾 DSN 的东西。该函数保留是因为它有 2 个调用方（`EnsureDB:26`、`initDBWithMigrateOnce:84`）。

> ⚠️ **50 处里有 3 处藏在死函数里，按「有效」口径它们记 0 分。**
> `utils/auth_jwt_config.go` 的 `LoadJWTFromViper()`（注释写着「RPC 使用」，而 go-zero RPC 已退役）、`ResolveAuthAccessSecret()`、`resolveAuthAccessSecret()`，以及 `utils/admin_jwt.go` 的 `LoadAdminJWTFromViper()`、`resolveAdminJWTSecret()` —— **全部零调用方**。活的接线是 `wiring/wire_svc.go:24` 与 `wiring/config_override.go:109` → `utils.ConfigureAdminJWT(secret, hours)`。这些是**删除**而不是迁移；把死代码指向新读法只会让噪音换个地方继续存在。
> 连带删掉 `envAuthAccessSecret = "MOE_AUTH_ACCESS_SECRET"` 常量 —— 它是 `derive.go:20` `envAuthSecret` 的重复定义。

> ⚠️ **`wechat` 那条链是「替换 + 消掉 10 个死键」，不是逐键平移。**
> `utils/wechat_oauth_flow.go` 的 `wechatFlowCredentials()` 对每个凭证尝试 3 种历史拼写（16 个键引用），其中 **10 个键在 config.yaml 里根本不存在**。`derive.go:177` 的 `WechatFlowCredential()` 已把这条链收敛成一次调用，所以整个函数与 `firstNonEmptyConfig()` 一并删除，文件只剩 `NormalizeWechatOAuthFlow`。
> `:36` 那句注释（「勿回退公众号(mp)：移动应用 code 只能用 wechat.app 凭证换取，混用会报 10005」）是**业务约束**，已确认原样保留在 `derive.go` 里，没有随 `switch` 被简化掉。
> **代价**：`NormalizeWechatOAuthFlow` 的归一化现在与 `derive.go:179` 的 `switch` 重复。这是结构上无法消除的 —— `utils` → `pkg/conf` → `utils` 会成环。

> ⚠️ **两处故意不改成「更干净」的写法**：
> 1. `internal/service/user/user_temp_mail.go` 的 `tempMailboxPassword()` 用 `conf.Get().Auth.AccessSecret`（**只读文件**），而不是 `conf.AuthAccessSecret()`（**env 优先**）。该值是临时邮箱口令的派生种子，让环境变量参与会导致「一旦设置 `MOE_AUTH_ACCESS_SECRET`，既有临时邮箱全部失效」。代码里留了注释说明。
> 2. `internal/biz/user/oauth_wechat.go` 保留 `conf.IsSet("wechat.enabled")`。两个分支产生**不同的用户可见文案**（「未配置微信登录」vs 通用 `ErrOAuthDisabled`），类型化的 `bool` 表达不了「未设置」与「显式 false」的区别。这也是 65 个剩余键字面量里 `wechat.enabled` 那 1 个的来源。

> 🔧 **顺带修掉一个会静默降级的文案耦合**：`oauth_wechat.go` 原来判 `strings.Contains(errText, "credentials missing")`，而 `conf.WechatFlowCredential` 返回的是 `"conf: wechat %s 凭证缺失（config.yaml）"`。不改的话错误文案会静默退化成通用的「微信授权失败，请重试」。已改为匹配 `"凭证缺失"`。
> 🔧 `provider_keys.go` 的 `providerKeysEncryptionSecret()` 是**已存 provider API 密钥的 AES 密钥来源**，任何行为变化都会让存量密钥解不开。已逐条核对 `conf.AuthAccessSecret()` 与原 `utils.ResolveAuthAccessSecret()` **字节级同义**（同样 env 优先、同样 `auth.access_secret` 兜底、同样已 trim）。

### 19.3 记账更正：序6 实收 33 键，不是预测的 38 键

§18.3 上一版预测序6 收敛 38 键 → 43.8%。实测 **33 键 → 39.0%**。**我自己的预测错了，此处按实测更正，不按预测记账。**

根因是少了一条判定规则，现已补进 §18.2：

> **一个键只有在其非 `pkg/conf` 读者归零时才算收敛。**

按这条，下面 5 个键虽然序6 已经把主要读者迁走了，但在**序2 的文件**里还有读者，所以不能记在序6 名下：

| 键 | 剩余读者（精确位置） | 归属 |
|----|-------------------|------|
| `auth.access_secret` | `internal/platform/wiring/config_override.go:98` · `cmd/temp-mail-password/main.go:60` | 序2 |
| `auth.access_expire_seconds` | `config_override.go:101` | 序2 |
| `admin.jwt_secret` | `config_override.go:104` | 序2 |
| `admin.token_expire_hours` | `config_override.go:105` | 序2 |
| `api.public_base_url` | `utils/admin_runtime_config.go:78`（读）· **`:97`（`v.Set` 写回）** | 序2 |

> **累计终点没变，只是拆分错了**：41 + 21 = 62 = 59.0%，与上一版「序6 + 序2 = 62」一致。所以文档的**总和**是对的，**分块**是错的。可执行的后果是计划变了 —— 上一版说「过 50% 必须序6 + 序2 一起做」，现在**序2 单独一步就过**。

> **分母 105 复核（曾算出 106，是个真 off-by-one）**：剩余 65 个键字面量里，`wechat.enabled` **既是已收敛、又仍是字面量**（在 `conf.IsSet()` 调用里），被两头各数了一次。剔除后未收敛 = 64，64 + 41 = **105** ✅。

### 19.4 新发现（已实测证实，本批未修）：`local_models.catalog` 的 `parameters_b` 是**活 bug**

§17.6(c) 把「`apiconfig.Config` 用 `json`/`yaml` 驼峰 tag，而 viper 要 `mapstructure`」登记为**迁移陷阱**。本次实测发现它不只是陷阱 —— **它今天就在丢数据**。

`internal/platform/apiconfig/config.go:23-32` 的 `LocalModelCatalogEntry` 实测有 **41 个 `json:` tag、0 个 `mapstructure:` tag**。`config_override.go:53` 用 `v.UnmarshalKey("local_models.catalog", &entries)` 灌它，走的是 mapstructure 的**默认按字段名大小写不敏感匹配**，于是带下划线的蛇形键匹配不上驼峰字段。用**非零合成值**跑对照实验（真配置里 `size_bytes: 0`，零值区分不出「被丢」还是「本来就是零」）：

| 字段 | config.yaml | `apiconfig` 路径（现网） | `pkg/conf` 路径 |
|------|------------|----------------------|---------------|
| `size_bytes` | 4242 | **0** ❌ | 4242 ✅ |
| `parameters_b` | 0.5 | **0** ❌ | 0.5 ✅ |
| `id`/`filename`/`sha256`/`description`/`recommended` | — | 全部正确 ✅ | 全部正确 ✅ |

规律很清楚：**只有含下划线的键被丢**（`size_bytes`→`SizeBytes`、`parameters_b`→`ParametersB`），单词键靠大小写不敏感匹配侥幸命中。

**影响必须精确界定，不能夸大成「两个字段都坏了」**：

- `SizeBytes` —— **被兜底掩盖**。`apicomm/local_models.go:108-111` 在 `size <= 0` 时回落到 `st.Size()`（磁盘真实大小），比配置值更准。加上 config.yaml 本来就写的 `size_bytes: 0`，**今天零可见影响**。
- `Sha256` —— 本来就匹配得上（无下划线），且 `:112-118` 另有真实 SHA256 兜底。
- `ParametersB` —— **无任何兜底**。`local_models.go:128` 直接透传 `entry.ParametersB`，配置里的 `0.5` 变成 `0`，经 `LlmLocalModelCatalogItem.parameters_b` 出到 API。**App 的离线模型列表把 Qwen2.5 0.5B 显示成 0B 参数。**

**已确认是既有缺陷，非本轮引入**：`git show HEAD:` 比对，`config_override.go` 的 catalog 块与 `apiconfig` 的 tag 缺失在 HEAD 上**逐字相同**；本轮对该文件的 diff 只删了 `ollama.*` 回退。

**修法与签字无关**：序3 的签字（§12.4）是关于 `MOE_LLM_*` 环境变量要开始影响 Bot 调度；而这个 bug 只需给 `apiconfig.LocalModelCatalogEntry` 补 8 个 `mapstructure` tag（或直接改用 `conf.Get().LocalModels.Catalog`，后者 tag 已正确），**零语义风险**。本批未动，等授权。

### 19.5 验证

不只看编译通过 —— 编译通过不等于有效，测试通过也可能只是死代码有守卫。

| 层级 | 手段 | 结果 |
|------|------|------|
| 编译/静态 | `go build ./...` · `go vet ./...` | 全绿 |
| 回归 | `go test ./...` | 全绿，除 `toolaudit.TestBuildSchemaItemsCoversAllTools`（**已用 HEAD worktree 复现同样失败，证明既有**，见 §17.6(b)） |
| 格式 | 逐文件 `gofmt -l` + 与 `git show HEAD:$f` 交叉比对 | 唯一未格式化文件 `utils/admin_runtime_config.go` 在 HEAD 上**已经**如此（§17.6(a) 那 92 个之一），非本轮引入 |
| **失败路径** | 从无 config 的目录跑真实二进制 | 响亮报 `config: conf: 未在 [...] 找到 config.yaml`，**退出码 1** ✅ |
| **快乐路径** | 一次性测试加载真 config.yaml，逐个打印新消费的 typed 字段 | 全部 `mapstructure` tag 正确填充 ✅ —— 这正是关掉 §17.6(c) 那个「静默零值」陷阱的关键，因为这些字段在本批之前**零消费方**，填错了不会有任何测试报警 |
| **全局单例归零** | 同口径 grep 对照 HEAD | 64 → **0**（见 §19.2 表） |

> ⚠️ **本轮差点又踩一次「空输出当通过」**：`gofmt -l $FILES` 对 33 个变更路径**什么都没打印**，我几乎据此写下「本批无格式漂移」。单独 `gofmt -l utils/admin_runtime_config.go` 却**确实**报了该文件。根因是路径列表里含 3 个已删除文件、且 `2>/dev/null` 把 gofmt 的报错吞了。改成逐文件跑、把 `$?` 与输出分开判、再逐个与 HEAD 交叉比对才得到真结论。**这与本次工作里三次算错分母是同一类错误：静默为空的校验命令是假清白，不是通过。**

---

## 20. 2026-09-09 第七批：序2 —— 有效收敛率 39.0% → 60.0%

序2 是「过 50%」那一步。按增量推进，每个增量单独过 gofmt / build / vet / test，避免一次性大改后无法定位。

### 20.1 迁移面：6 个增量、6 个文件

| 增量 | 文件 | 覆盖的段 | 收敛方式 |
|------|------|---------|---------|
| 2a | `internal/platform/wiring/config_override.go` | `app_client` · `image`(含 OSS 8) · `auth` · `admin` | `conf.Get()` 快照 + `conf.AuthAccessSecret()` + `conf.AdminJWT()` + `conf.IsSet("image.oss.proxy_via_api")`。**`llm_inference.*` 与 `local_models.*` 故意留在本地 `v` 上给序3** |
| 2b | `internal/platform/moewiring/api_post.go` | `image` · `runtime` | `imageConfigFromMoe()` 整体改读 `conf.Get().Image`；`handDrawRequireModeration()` → `conf.Get().Runtime.HandDrawRequireModeration`。顺带删掉 `if v == nil` 守卫（`conf.Get()` 不返回 nil，零值 `ImageConfig` 等价）与那段已过期的注释 |
| 2c | `cmd/migrate-media-oss/main.go` | `image` | `-conf` 是**目录**，故用 `conf.LoadFile(filepath.Join(dir,"config.yaml"))` 而非 `Load()`（后者只搜固定三目录） |
| 2d | `utils/admin_runtime_config.go` | `app_client` · `api` · `image` | **读路径**改 `conf.Reload()`（5 个 typed 字段）；**写路径按 §18.3 预判保留 viper**（`v.Set()` ×5 + `WriteConfig()`），并在写回后补 `conf.LoadFile(path)` |
| 2e | `cmd/temp-mail-password/main.go` | `auth` | `-f` → `conf.LoadFile`，失败时保留原有的 `backend/` 前缀重试。**口令种子仍只取文件值**，不用 `conf.AuthAccessSecret()`（理由同 §19.2 故意偏离 1） |
| 2f | `internal/platform/moesocial/startupconfig.go` | `runtime` · `moe.production` | 删掉私有 `viperForUnified()`，改 `loadUnified()` → `conf.LoadFile(-f)`；`httpPortFromUnified()` 收敛到既有的 `conf.HTTPPort()`（`derive.go:126` 的注释本就写着「与 moesocial.httpPortFromUnified 一致」，此前零调用方） |

> 🔧 **2d 修掉了 §18.3 障碍 2**：`conf.Reload()` 此前零调用方，而 `conf.Get()` 首次加载后永久缓存。管理台写回 config.yaml 后若不失效缓存，「改了图片配置不生效」会从局部小问题升级成全局问题。现在 `Reload()` 有 1 个调用方（`:76`），写回后再 `conf.LoadFile(path)`（`:119`）让缓存指向刚写的文件 —— `load.go:114` 那条注释要求的东西，到此才真正存在。
> 🔧 **2e 的等价性是逐条核对的，不是假定的**：CLI 的 `tempMailboxPassword` 与 `internal/service/user/user_temp_mail.go:390-399` 字节级同构（同样 `TrimSpace(只读文件的 secret)` → 同样兜底 `"moe-social-temp-mail"` → 同样 `sha256(email|seed)` 取前 16 字节 hex）。改完后用 HEAD worktree 跑同一条命令对照，口令 `2ad900214b50fed06ff1a64a752ab798` **两边完全一致**。

### 20.2 口径 F 实测

| 指标 | 序6 后 | **序2 后** |
|------|-------|----------|
| 出现次数 | 116 | **68** |
| 唯一键字面量 | 65 | **49** |
| 其中**真有非 `pkg/conf` 读者**的键 | 64 | **42** |
| 涉及文件 | 31 | **28** |
| `pkg/conf` 反向依赖 | 17 | **23** |
| 遗留 `viper.New()` | 19 | **16** |
| **有效收敛率** | 41/105 = 39.0% | **63/105 = 60.0%** |

**49 与 42 的差是 7 个「有字面量但已无读者」的键**，必须逐类说清，否则会被当成漏迁：

| 类别 | 键 | 为什么不是读者 |
|------|----|--------------|
| `conf.IsSet()` 实参（3 处） | `wechat.enabled` ×2 · `image.oss.proxy_via_api` ×1 | 调的是 `pkg/conf` 自己的 API。保留 `IsSet` 的理由见 §19.2 故意偏离 2（要区分「未设置」与「显式 false」）与 §18.3（OSS 覆盖语义） |
| `v.Set()` 写回（5 处） | `api.public_base_url` · `app_client.public_api_base_url` · `image.public_base_url` · `image.local_dir` · `image.max_bytes` | `pkg/conf` **没有 setter**，管理台的写路径只能留在 viper。这是**写**不是读 |

剩下 42 个真读者 = `moe.*` 30 + `llm_inference.*` 10 + `local_models.*` 2，正好是序3（12）与序4/序5（30）。

### 20.3 本批唯一的行为变化：`-f` 从此对全进程权威

2f 之前，`conf.LoadFile()`（`load.go:100`，注释写着「对应 cmd/moe-social 的 -f 覆盖」）**零调用方**。后果是同一次启动读两个文件：`-f` 只决定 API 片段路径与 HTTP 端口，而 DSN、JWT 密钥、图片配置等所有 `pkg/conf` 读者走的是 `searchDirs`。

用 HEAD worktree 跑同一份探针做**负对照**，把这个裂脑拍成了实证：给 `-f /tmp/…/alt.yaml`（内含 `http_port: 9955`），HEAD 上端口确实取到 9955，但 `conf.Path()` 仍是 `backend/config/config.yaml` —— **端口来自 A 文件，其余一切来自 B 文件**。改完后该断言通过，并已固化为常驻回归测试 `TestUnifiedFlagIsAuthoritativeForAllReaders`（同一测试在 HEAD 上 FAIL，在新代码上 PASS）。

> ✅ **对现有部署零可观测变化**，这一点是逐个入口核过的，不是推定的：
>
> | 入口 | `-f` 实际取值 | cwd | 解析结果 |
> |------|-------------|-----|---------|
> | `backend/Makefile:67` | 无（用 flag 默认 `config/config.yaml`） | `backend/` | `backend/config/config.yaml` = `searchDirs[0]` |
> | `backend/Dockerfile:20` | `config/config.yaml` | `WORKDIR /app`（`:17` 把配置 COPY 到 `/app/config/config.yaml`） | 同一文件 |
> | `deploy/n100/moe-social.service:9` | `config/config.yaml` | `WorkingDirectory=%h/moe-runtime`（`:8`） | 同一文件 |
>
> 三处都是相对路径 `config/config.yaml`，与其 cwd 下的 `searchDirs[0]` 指向**同一个文件**，所以 `LoadFile` 与 `Load` 结果相同。
> ✅ `-f` 读不到时回落 `searchDirs`，与迁移前 `viperForUnified()` 的静默回退**逐条等价**（`load.go:14` 的 `searchDirs` 与被删的 3 个 `AddConfigPath` 顺序一致）。
> ✅ 启动顺序核过：`run_http_only.go:18` 的 `NormalizeOptions()` 先跑（→ `loadUnified` → `LoadFile`），`:19` 的 `conf.Load()` 后跑；而 `Load()` 在 `current != nil` 时直接返回缓存，**不会把 `-f` 覆盖回 searchDirs**。失败路径也保留：`-f` 与 searchDirs 都读不到时 `:19` 仍然响亮返回 error。
> ✅ 全仓无包级 `var … = conf.Get()/Load()` 持有旧指针（实测 grep 为空），故替换缓存不会产生陈旧快照。

### 20.4 验证

| 层级 | 手段 | 结果 |
|------|------|------|
| 编译/静态 | `go build ./...` · `go vet ./...`（单独判 `$?`，不经管道） | 全绿，vet 输出 0 行、退出码 0 |
| 回归 | `go test ./...` | 32 包 ok，唯一失败仍是 `toolaudit.TestBuildSchemaItemsCoversAllTools`（§17.6(b)，已用 HEAD worktree 证明既有） |
| 格式 | `gofmt -l` 逐目录 | 本批 6 个文件零漂移 |
| **2c 真机执行** | 跑真实二进制；再只给假的 `MOE_OSS_*` 环境变量跑一次 | 后者能走到 `found 0 local objects under /app/data/images`，证明 endpoint/bucket/local_dir **确实来自文件**而不是环境变量 |
| **2d 往返探针** | 临时目录里做 读 → 写回 → 重载 五断言 | 全过；真 `config/config.yaml` 的 sha 前后均为 `dec63ea4a3e0c59c68d823bbabb1c768117e46db`，**未被探针改动** |
| **2e 等价对照** | HEAD worktree 跑同命令，覆盖 `-email` / `-json` / 位置参数 / 仓库根启动 / 不存在的 `-f` / 非法邮箱 六条路径 | 口令全部逐字相同；唯一差异是失败文案多了 `conf: 读取 <file> 失败:` 前缀（**更响**，退出码同为 1） |
| **2f 端到端启动** | 复制真配置到临时文件、改 `runtime.http_port: 18899`，`moe-social -f <tmp>` 真实启动 | 9 秒 ready，**监听 18899 而非 8888**，`curl` 返回应用级 `401 {"code":401,"message":"缺少认证信息，请先登录"}`（证明路由+鉴权中间件全链路通）；8888 未被占用；关停后端口释放 |
| 安全闸复跑 | 全局单例直读 grep（含 HEAD 对照） | 工作树 **0**，HEAD **64** —— 序6 的闸门在序2 之后依然成立 |

启动日志同时佐证了 2a/2b：`图片: dir=/app/data/images public=http://47.106.175.49:8888 max=1073741824` —— 三个值都来自那份临时 `-f` 文件经 `conf.Get().Image` 的 typed 路径。

### 20.5 顺带实测到的既有缺陷（本批未修）：10 个文件自带 `searchDirs`，永远看不见 `-f`

2f 的启动实验意外给出裂脑的**现场证据**：我在临时 `-f` 文件里把 `moe.bot_scheduler_enabled` / `moe.dream_scheduler_enabled` / `moe.life_engine_enabled` 都写成 `false`，日志却照样打出 `moe bot scheduler started tick=1m0s` 与 `moe dream scheduler started tick=5m0s`。

根因不是 flag 失效，而是**读它的地方根本不读 `-f` 那个文件**：`pkg/moe/runtime/config_load.go:64-70` 与 `pkg/moe/brain/dream_schedule.go:96` 各自 `viper.New()` + 硬编码三个 `AddConfigPath`，于是加载的是 `backend/config/config.yaml`（真配置里这两个开关是 `true`）。

实测带硬编码 `searchDirs` 的文件共 **10 个**（`config_override.go` 剩余部分、`moewiring/config.go`、`apicomm/inference_props.go`、`moeconfig/inference.go`、`pkg/moe/runtime/config_load.go`、`pkg/moe/runtime/post_model.go`、`pkg/moe/brain/` 下 4 个），正是序3 + 序4/序5 的迁移面。**在它们迁完之前，`-f` 仍然只对 `pkg/conf` 读者权威** —— 这一条必须写在明处，否则「`-f` 已权威」会被误读成全局成立。

> ⚠️ **一处需要更正的说法，以及一个顺带查出的死键。** 我原先想写「序3/序4/序5 同样不需要新字段，`Moe` 结构体 31 个 `moe.*` 叶子键已齐」——**实测不成立**，逐键核对后的真实情况是：
>
> | | 数量 | 明细 |
> |---|---|---|
> | config.yaml 的 `moe.*` 叶子键 | **31** | — |
> | `pkg/conf` 已覆盖 | **28** | 12 个静态 `mapstructure` tag（`config.go:212-230` + `MoeProduction` 5 个，其中只有 12 个在 config.yaml 里真被设置）+ 16 个动态 `moe.<domain>_api_in_process`（`derive.go:199-217` 的 19 域表拼出，config.yaml 里实际写了 16 个） |
> | **未建模** | **3** | `moe.default_capability_tier` · `moe.bot_post_daily_limit_default` · **`moe.enabled`** |
>
> 前两个**不是遗漏**：`pkg/conf/config.go:17-22` 那段注释已把它们连同 `server.*`、`memory.search/embedding.*`、`temp_mail.api_key` 一起登记为「全仓无 Go 读者、故意不建模」的死键。
> 第三个 **`moe.enabled` 是本批新查出的死键**：`git grep` 全仓（Go 与非 Go）**零引用**，config.yaml 里 `enabled: true` 静静躺着，且它**不在** `config.go` 那份死键清单里 —— 那份清单自称「逐个 grep 确认过，不是漏掉」，这一条就是漏掉的。已补进注释。
>
> ✅ **所以「序4/序5 不需要新增结构体字段」这个结论仍然成立，但理由要换**：不是因为 31 个键都建模了，而是因为 28 个**活键**已全部建模，剩下 3 个是死键（处置方式应是删配置或继续留注释，不是加字段）。这也与 §18.3「已扣除死键」的分母口径一致 —— 105 里本来就不含它们。

---

## 附录 A：复核命令

```bash
# 密钥是否入库
git ls-files --error-unmatch backend/config/config.yaml
grep -nE 'app_secret|password:|access_secret|jwt_secret' backend/config/config.yaml
grep -n 'moe123456' android/app/build.gradle.kts

# env 通道是否集中
grep -rn 'os.Getenv("MOE_' backend/ --include='*.go' | grep -v _test
grep -rn 'godotenv\|AutomaticEnv\|BindEnv\|env_file' backend/    # 应为空

# 地址副本
grep -rn '47\.106\.175\.49\|192\.168\.' --include='*.yaml' --include='*.dart' \
     --include='*.go' --include='*.ts' --include='*.conf' --include='*.js' . \
  | grep -v node_modules | grep -v '/build/'

# 死配置
grep -rn 'super\.yaml' backend/ --include='*.go' | wc -l           # 0
grep -rn 'RemoteApiConfigService' lib/                             # 仅自引用
grep -rn 'FeatureFlags.showLocalModelSettings' lib/                # 0

# 键名写回 bug
grep -ni 'publicbaseurl\|public_base_url' backend/utils/admin_runtime_config.go

# 部署入口不一致
grep -n 'cmd/moe-social' .github/workflows/n100-deploy.yml backend/Makefile
grep -n 'ops' moe-admin/deploy/sync-lan.ps1 .github/workflows/n100-deploy.yml

# 仓库卫生
git ls-files | grep -E 'moe_ui\.xml|_hero_orig|cover\.out|duplication-report|pet_exists'

# §18 进度口径 F：配置键引用（按数据形态计，不按调用形态枚举，见 §18.1）
# ⚠️ 必须在**仓库根**执行。EXCL 的四个模式都是 `backend/…` 前缀，
#    若在 backend/ 里跑，路径变成 ./pkg/conf/…，排除会**静默全部失效**，
#    数出来 129/78 而不是 116/65（本轮实测踩过）。
SECTIONS='database|runtime|auth|admin|app_client|image|Image|local_models|llm_inference|ollama|feishu|wechat|private_message|temp_mail|moe|memory|server|jwt|api'
KEYRE="\"($SECTIONS)(\.[A-Za-z0-9_]+)+\""
EXCL='_test\.go|backend/pkg/conf/|backend/deploy/|backend/api/'
grep -rnE "$KEYRE" backend/ --include='*.go' | grep -vE "$EXCL" > /tmp/F_WORK.txt
grep -oE "$KEYRE" /tmp/F_WORK.txt | wc -l                 # 出现次数 → 68（基线 254 / 第五批后 192 / 序6后 116）
grep -oE "$KEYRE" /tmp/F_WORK.txt | tr -d '"' | sort -u | wc -l   # 唯一键 → 49（基线 155 / 第五批后 118 / 序6后 65）
cut -d: -f1 /tmp/F_WORK.txt | sort -u | wc -l             # 涉及文件 → 28（基线 48 / 第五批后 46 / 序6后 31）
grep -c 'backend/pkg/conf/' /tmp/F_WORK.txt               # 必须 0，否则 EXCL 失效（见上面的 ⚠️）
# 唯一键 ≠ 未收敛键：49 里有 7 个已无读者（3 处 conf.IsSet 实参 + 5 处 v.Set 写回，见 §20.2）。
# 有效收敛率的分子必须用「真读者」这一列，否则会把写路径当成漏迁。
grep -vE '\.Set\(|conf\.IsSet\(' /tmp/F_WORK.txt > /tmp/F_READ.txt        # 真读者命中 → 59
grep -oE "$KEYRE" /tmp/F_READ.txt | tr -d '"' | sort -u | wc -l           # 真读者唯一键 → 42
# 有效收敛率 = (105 - 42) / 105 = 63/105 = 60.0%；42 按段分布应为 moe 30 · llm_inference 10 · local_models 2
grep -oE "$KEYRE" /tmp/F_READ.txt | tr -d '"' | sort -u | awk -F. '{print $1}' | uniq -c
# 基线同口径（git grep -E 不支持 \b，只能用字符类；输出前缀 HEAD: 要剥掉）
git grep -nE "$KEYRE" HEAD -- 'backend/*.go' | sed 's/^HEAD://' | grep -vE "$EXCL" > /tmp/F_HEAD.txt
# 唯一键差集 = 本批消失的键，逐个分类成「已迁移」还是「死键删除」（§18.2 那张表）
comm -23 <(grep -oE "$KEYRE" /tmp/F_HEAD.txt | tr -d '"' | sort -u) \
         <(grep -oE "$KEYRE" /tmp/F_WORK.txt | tr -d '"' | sort -u)
# 反向校验：找出「有键字面量但该行不含任何查找调用」的行，即 §13.3 的命中≠消费
# 注：firstViperString/firstViperInt64 已随 §19.1 批6a 删除，firstNonEmptyConfig 已随 §19.2 序6 删除，
#     留在正则里是为了仍能扫描 HEAD 及更早的快照。
LOOKUP='(v|v2|viper|moeViper\(\))\.(GetString|GetInt|GetInt64|GetBool|GetFloat64|GetStringSlice|IsSet|GetDuration|UnmarshalKey|Set)\(|first(NonEmptyString|PositiveInt64|NonEmpty|ViperString|ViperInt64|NonEmptyConfig)\(|boolOr\(|domainInProcessEnabled\(|getBool\('
grep -vE "$LOOKUP" /tmp/F_WORK.txt

# 收敛的真实指标：pkg/conf 的反向依赖（§16.2 / §19.2 / §20.2）
grep -rln '"backend/pkg/conf"' backend/ --include='*.go' \
  | grep -v 'backend/pkg/conf/' | grep -v '_test.go' | wc -l              # → 23（基线 0 / 第五批后 1 / 序6后 17）
grep -rn 'viper\.New()' backend/ --include='*.go' \
  | grep -v '_test.go' | grep -v 'backend/pkg/conf/' | wc -l              # → 16（基线 20 / 序6后 19）

# 序6 的决定性安全闸：全局单例直读必须归零（§19.2）
# ⚠️ 空输出要用 HEAD 对照验证正则本身有效，否则是假清白（HEAD 应为 64）
GS='viper\.\(GetString\|GetInt\|GetInt64\|GetBool\|IsSet\|Set\|Get\|ConfigFileUsed\|ReadInConfig\|SetConfigName\|AddConfigPath\)('
grep -rn "$GS" backend/ --include='*.go' | grep -v '_test.go' | grep -v 'backend/pkg/conf/' | wc -l   # → 0
git grep -n "$GS" HEAD -- 'backend/*.go' | grep -v '_test.go' | grep -v 'backend/pkg/conf/' | wc -l   # → 64（对照组）
grep -rn 'InitConfig' backend/ --include='*.go'          # → 仅 pkg/conf/config.go:3 的注释，0 处代码

# 序2 的两道闸（§18.3 障碍 2 / §20.3）：这两个函数此前都是零调用方
grep -rn 'conf\.Reload()' backend/ --include='*.go'      # → 1 处：utils/admin_runtime_config.go:76（序2 前为空）
grep -rn 'conf\.LoadFile(' backend/ --include='*.go' | grep -v 'backend/pkg/conf/'
#   → 5 处：migrate-media-oss:31 · temp-mail-password:51,52 · moesocial/startupconfig.go:58 · admin_runtime_config.go:119
# -f 权威性的常驻回归测试（该测试在 HEAD 上 FAIL，见 §20.3）
go test ./internal/platform/moesocial/ -run TestUnifiedFlagIsAuthoritativeForAllReaders
# §20.5：仍然看不见 -f 的文件（各自硬编码 searchDirs）→ 10 个，即序3 + 序4/序5 的迁移面
grep -rln 'AddConfigPath("\.\./\.\./config")' backend/ --include='*.go' \
  | grep -v '_test.go' | grep -v 'backend/pkg/conf/' | wc -l              # → 10
# §19.4 的活 bug：apiconfig 缺 mapstructure tag
grep -ohE '`(json|yaml|mapstructure):' backend/internal/platform/apiconfig/*.go | sort | uniq -c   # → 41 json / 0 mapstructure
```

---

## 相关文档

- [环境配置说明.md](./环境配置说明.md) — 本地 / 线上 API 基址（✅ §14 已重写，与 `ApiEnvConfig` 一致）
- [app-release-cheatsheet.md](./app-release-cheatsheet.md) — 发版速查（含 §14.1 的发布前断言步骤与排错表）
- [app-usability-upgrade-plan.md](./app-usability-upgrade-plan.md) — P0-A 记录「不引入构建变量」的原始约束，及断言为何不违反它
- [API调试指南.md](./API调试指南.md) · [快速调试步骤.md](./快速调试步骤.md) — ✅ §14.4 已清除失效的 `_isProduction` / cpolar / 按平台分支说法
- [应用配置与全局常量分层约定.md](./应用配置与全局常量分层约定.md) — Flutter 侧配置分层（**待补环境基址归属**；同名 `AppConfig` 冲突已消除）
- [ports.md](./ports.md) — 本地端口表（**§4.2 指出存在越界硬编码**）
- [kratos-migration-status.md](./kratos-migration-status.md) — Kratos 迁移状态板
- [full-review-2026-09-02.md](./full-review-2026-09-02.md) — 上一次全栈审查快照
- [deploy-platform.md](./deploy-platform.md) — 云平台部署
- [n100-pipeline.md](./n100-pipeline.md) — n100 预发流水线
- [security-and-stability-backlog.md](./security-and-stability-backlog.md) — 安全待办
