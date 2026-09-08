# 配置治理审查（2026-09-08）

> **范围**：`backend/` · `lib/` · `moe-admin/` · `website/` · `deploy/` · `.github/workflows/` · 仓库卫生
> **基线提交**：`14370f93 feat: 批量更新LLM推理链路与管理台体验`（2026-09-06）
> **性质**：只读审查，本文不含任何代码改动。所有结论均给出 `文件:行号` 证据，可按附录 A 的命令复核。
> **有效性**：本文是**绑定基线提交 `14370f93` 的快照**（依 `docs/README.md` 文档维护约定第 3 条）。§11 各批次整改落地后，对应章节即失效，应**直接删除该章节**而非保留 archive stub。所有行号以该基线为准，后续提交可能使其偏移。
> **前提说明**：当前仓库内的第三方密钥为**开发期临时凭据，正式版会整体更换**。因此本文的重点不是「密钥泄露应急」，而是**为什么结构上会导致密钥只能写在这里**——结构不改，换完新密钥仍会回到同一状态。

---

## 0. 结论速览

一句话：**项目有 5 个运行环境，但没有环境抽象层**，于是每个环境的值都被硬写进各处被 git 跟踪的文件里，靠人工同步。

| # | 问题 | 严重度 | 关键证据 | 整改批次 |
|---|------|--------|----------|----------|
| 1 | 明文凭据在被跟踪的 `config.yaml` 内 | P0 | `backend/config/config.yaml:11,23,28,51,81,256` | 批次 1 |
| 2 | Android release 签名口令有明文 fallback | P0 | `android/app/build.gradle.kts:27,29` | 批次 1 |
| 3 | 同一 API 地址有 14 处运行时副本 | P1 | 见 §4.1 表 | 批次 3 |
| 4 | 改 yaml 可能不生效（Go 硬编码短路 / 键名写错） | P1 | `moewiring/config.go:62-131`、`admin_runtime_config.go:79,100` | 批次 2 |
| 5 | 「SSOT」声明与实际真源不符（Agora 段） | P1 | `api/etc/moe.yaml:12` vs `config.yaml` 无该段 | 批次 2 |
| 6 | 端口 SSOT 被越界硬编码 | P2 | `moewiring/config.go:169,184,189` | 批次 2 |
| 7 | 死配置 / 摆设开关制造噪音 | P2 | 见 §6 表（`.env`、`super.yaml`、20 个 `*_api_in_process`） | 批次 4 |
| 8 | 切环境 = 改源码 + 重启 + 提交 | P1 | `lib/utils/config.dart:16`、提交 `96d7a612` | 批次 3 |
| 9 | 服务器配置与仓库配置已永久分叉 | P1 | `backend/scripts/vps-switch-companion-model.sh` | 批次 5 |
| 10 | 4 套部署链互不知情，两条会互删产物 | P1 | `sync-lan.ps1:12,24` vs `n100-deploy.yml:57` | 批次 5 |
| 11 | 调试产物被提交进仓库 | P3 | `moe_ui.xml`、`cover.out`、`duplication-report/` | 批次 6 |
| 12 | 文档描述的配置机制与代码不符 | P2 | 见 §9 表 | 批次 6 |
| 13 | ~~本机拉起后端默认直连生产 MySQL root~~ **已澄清：该库是测试库** | ~~P0~~ → 非问题 | 需求方确认 `47.106.175.49` 为**测试库**，开发机直连属预期便利；凭据入库的问题归入第 1 行 | 不整改 |
| 14 | 文档教的启动命令已整体失效（`make rpc` / `go run super.go`） | P1 → **已完成** | `backend/rpc/` 目录不存在；见 §9.1（2026-09-08 已清理脚本、Go 提示串与 11 份文档） | 批次 6 ✅ |
| **15** | **同一份 `config.yaml` 被 20 处独立打开，回退链各自实现** | **P1** | 见 §12（19 个 `viper.New()` + `utils.InitConfig()` 全局单例，其中 LLM 有两条不一致的链） | 批次 2（已建 `backend/pkg/conf`，待迁调用点） |

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

| 端口 | 硬编码位置 | 是否在 ports.md 表内 |
|------|-----------|---------------------|
| `18888` | `moewiring/config.go:169` | ✗ |
| `19032` | `moewiring/config.go:184,189` | ✗（超出 19010–19019 预留段） |
| `6633` | `config.yaml:103`、`api/etc/moe.yaml:18` | ✗ |
| `11434` | `config.yaml:97`、`llminference/client.go:70` | ✗ |

`19032` 还同时出现在 `internal/conf/moe/v1/pilot.pb.go:229`、`api/vip/v1/vip_read.pb.go:27`、`api/moe/v1/moe_grpc.pb.go:60,378` 的注释与生成物里，以及 `openapi.yaml:14370,14415`。端口注册表存在但未被强制。

---

## 5. P1 — 真源冲突：改了配置但不生效

`backend/config/config.yaml:5` 自称「统一配置（SSOT，PK-13）」。实际有 5 类破口：

### 5.1 Agora 段的唯一真源不是 SSOT

`api/etc/moe.yaml:12` 定义了 `Agora:` 段，而 `config.yaml` 中**完全不存在** `agora`（已 grep 确认）。`config_override.go` 也没有对应分支。→ 语音通话凭据的唯一真源是那个被称作「片段」的文件，直接违反 SSOT 声明。

### 5.2 「非空才覆盖」导致片段残留值生效

`config_override.go:14-126`（`ApplyUnifiedConfigOverrides`）的所有分支都是 `if v := ...; v != "" { 覆盖 }`。因此 `api/etc/moe.yaml` 里的残留值会在 `config.yaml` 未显式设置时**静默生效**，例如 `moe.yaml:18` `BaseUrl: http://127.0.0.1:6633`、`:20` `TimeoutSeconds: 300`。

### 5.3 Go 硬编码短路 yaml

`internal/platform/moewiring/config.go`：

- `:62-64`、`:86-88`、`:97-99` — `KratosPilotReadEnabled()` 为 true 时直接 `return true`，yaml 值被短路
- `:112-131` — `KratosPureEnabled()` 为 true 时强制 `KratosHTTPFrontEnabled` / `KratosGRPCManaged` / `KratosSuperGRPCNative` 全部 true
- `:148-156` — 强制 `fallback = false`
- `:133-146` — `KratosPK8GoctlRetired()` / `KratosPureHTTPWithoutLegacy()` 恒定 `return true`

而以下键**在 `config.yaml` 里根本不存在**，只能走 Go 默认值，在配置文件里既看不到也改不动：
`kratos_internal_http_port`、`kratos_pilot_read_enabled`、`kratos_http_front_enabled`、`kratos_grpc_managed`、`super_grpc_retired`、`pilot_process_deprecated`、`kratos_hybrid_http_fallback`。

### 5.4 同一个键有两条读取路径

`KratosAdminBaseURL()`（`config.go:176-190`）先查 `moeconf.LoadBootstrap()`（另一份基于 proto 的加载器，`moeconf/load.go:27-37`），未命中再回落 `moeViper()`，最后兜底 `http://127.0.0.1:19032`。而 `config.yaml:227` 写的是 `kratos_admin_base_url: "http://127.0.0.1:8888"`。同一个键、两个 loader、三个可能结果。

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
> `_runtimeProductionBaseUrl` 间接层已删，`initRemoteProductionBaseUrl()` 已更名为 `initBaseUrlFromAppConfig()`。
> **`backend/.env` 一行已失效**：复核发现该文件磁盘上不存在、git 历史里也从未入库（`.gitignore:99-100` 已覆盖 `.env` / `.env.*`），原分析针对的是一个本地未跟踪文件。
> **仍未处理**：`moe.*_api_in_process` 开关族（含隐藏的 3 个）、两个同名 `AppConfig`、`api.timeout_ms`（本轮新查明：只写不读）。

| 项 | 状态 | 证据 |
|----|------|------|
| `backend/.env` | ✅ **一行已失效**：磁盘上不存在，git 历史里也从未入库 | `ls backend/.env` → No such file；`git log --all -- backend/.env` → 空；`.gitignore:99-100` 已覆盖 `.env` / `.env.*` |
| `backend/api/etc/super.yaml` | ✅ **已删**。原 37 字节、零 Go 引用，却被文档当作 CORS/监听真源 | 删除后 `go build ./...` 通过；悬空文档引用已修（见 §9.2） |
| `MOE_SUPER_RPC_ENDPOINT` | ✅ **已删**。原只存在于 `config.yaml:35` 的注释里，却指导运维去设一个无人消费的环境变量；连同 `api.super_rpc_endpoints`（已注释）与 `api.super_rpc_timeout_ms`（活键但零读者）整块移除 | `grep -rn 'super_rpc_timeout_ms\|MOE_SUPER_RPC_ENDPOINT' backend/ --include='*.go'` → 0；注意 `moe.pilot.super_rpc_endpoint` 是**另一个键**，`moeconf/load.go:62` 仍在读，保留 |
| 20 个 `moe.*_api_in_process` | `config.yaml:204-225` 全部为 true（含 `:225 single_process`），而兜底默认值 `defaultInProcessEnabled()`（`moewiring/config.go:43-45`）也是 true → **20 个键的信息量等于 1 个键** | 分支确实存在（`wiring/wire_community.go:12-84` 等 20 处），但关掉会导致 `ctx.XxxApp` 为 nil，无人会关 |
| 隐藏的 3 个开关 | `moe.game_api_in_process`（`api_game.go:13`）、`moe.notify_api_in_process`（`api_notify.go:10`）、`moe.life_api_in_process`（`api_life.go:10`）代码在读，yaml 里没写 | 只能靠默认值，配置文件里不可见 |
| `lib/config/moe_api.json` + `RemoteApiConfigService` | ✅ **整条链已删**。原无调用方：`lib/main.dart:195` 调的方法只读 `AppConfig`、不访问网络 | 删除后 `flutter analyze` 无 error/warning；方法已更名 `initBaseUrlFromAppConfig()`（见下一行） |
| `api.timeout_ms` | **只写不读**（本轮新查明）：`wiring/config_override.go:68` 灌进 `apiconfig.Config.Timeout`，全仓无任何读者 | `grep -rn '\.Timeout\b' backend/ --include='*.go'` 命中的三处 `cfg.Timeout` 属 `llminference.Config`（`time.Duration`），与本键无关；LLM 超时实际由 `llm_inference.timeout_seconds` 决定。已在 `config.yaml` 注释标注，键本身待第 2 步随 `apiconfig` 一并清除 |
| `FeatureFlags.showLocalModelSettings` | ✅ **已删**（原 0 处引用） | `grep -rn 'showLocalModelSettings' lib/` → 0 |
| `FeatureFlags.companionSingleActiveBondPhase1` | ✅ **已删**。原仅出现在 `companion_service.dart:605` 的注释里，该注释已改写为不依赖此常量 | `grep -rn 'companionSingleActiveBondPhase1' lib/` → 0 |
| `FeatureFlags.showExperimentalFeatures` | 无直接判断，仅用于派生 `showAutoGlm`（`showLocalModelSettings` 已删，派生对象只剩一个） | `feature_flags.dart:19,25` |
| `FeatureFlags.showGachaFeatures` | 仅 1 处挡路由（`app_routes.dart:223`） | 半死 |
| `_runtimeProductionBaseUrl` | ✅ **已删**。原为残留间接层：local 模式为 null，online 模式直接赋 `_configuredOnlineUrl`，恒等于配置值 | `baseUrl` getter 改为直接返回 `_configuredOnlineUrl`，行为等价（被删字段在 local 模式下根本不被读取）；同时 `initRemoteProductionBaseUrl()` → `initBaseUrlFromAppConfig()`，名字不再暗示「远程拉取」 |
| 两个同名 `AppConfig` 类 | `lib/utils/config.dart:14`（环境基址）vs `lib/config/app_config.dart`（AI 配置读写），靠 `api_service.dart:29` 的 `as moe_launch_config` 别名规避 | 违反 `应用配置与全局常量分层约定.md` 的分层规则 |
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
| `docs/dev/环境配置说明.md:13` | `developmentUrl = 'http://127.0.0.1:8888'` | `lib/utils/config.dart:25` 是 `http://192.168.124.36:8888`。**仍未处理**——属 §7.1 前端 IP 管理，随该批次一起做 |
| `docs/dev/环境配置说明.md`（后端服务节） | 「后端监听与 CORS 见 `config.yaml`、`backend/api/etc/super.yaml`」 | ✅ **已修**：`super.yaml` 已删，该文档现已不含此引用 |
| `docs/dev/飞书OAuth授权验证指南.md:16,26` | 要求 `redirect_uri` 与 `lib/config/moe_api.json` 的 `api_base_url` 指向同一台 API | ✅ **已修**：`moe_api.json` 已删，两处改指 `lib/utils/config.dart` 的 `AppConfig.productionUrl`；`:93` 同类引用一并修掉 |
| `docs/dev/moe-admin.md:114,117` | deploy target `api_base_url: http://47.106.175.49:8888` | 与 n100 链路（`192.168.124.77`）并存，未说明何时用哪个。**仍未处理** |
| `backend/config/config.yaml:35` 注释 | 「Docker 推荐用 compose 环境变量 `MOE_SUPER_RPC_ENDPOINT=rpc:8080`」 | ✅ **已修**：该注释连同 `api.super_rpc_endpoints` / `api.super_rpc_timeout_ms` 整块删除（三者全仓零读者） |
| `lib/services/api_service.dart:192` 注释 | 「勿再使用 `api_env.json`」 | ✅ **已修**：`api_env.json` 仓库中已不存在，该引用已删 |
| `ApiService.initRemoteProductionBaseUrl()` | 方法名暗示「从远程拉取生产基址」 | ✅ **已修**：更名 `initBaseUrlFromAppConfig()`，同步改 `main.dart:195`、`auth_service.dart:93`、`环境配置说明.md:7` |
| `docs/dev/应用配置与全局常量分层约定.md` | `lib/config/**` 放行为、`lib/constants/**` 放数据定义 | 环境基址这个最核心的配置在**第三个位置** `lib/utils/config.dart`，且与 `lib/config/app_config.dart` 的类名冲突。**仍未处理**（结构性，属批次 3） |
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
> `8080` / `19011` / `18888` / `19032` / `6633` 五个端口**已无任何监听者**，仅存在于死代码的硬编码兜底里。

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

### 10.1 被提交的调试产物 ✅ 已基本清理（2026-09-08，尚未提交）

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
| Flutter 改用 `--dart-define=API_BASE_URL=...` + 构建类型绑定，删除 `isProduction` 常量；`developmentUrl` 不再硬编码具体内网 IP | `flutter build apk --release` 无需改任何源码；debug/release 自动对应不同基址 |
| `showGameNetworkLab` 纳入同一构建期注入机制，并在 CI 加发布卡点（release 构建时断言实验开关为 false） | 无法构建出携带实验 VPN 能力的 release 包 |
| ✅ **已完成（2026-09-08）**：删除 `lib/config/moe_api.json` 与 `lib/services/remote_api_config_service.dart`；`initRemoteProductionBaseUrl()` 更名为 `initBaseUrlFromAppConfig()`（连带删掉 `_runtimeProductionBaseUrl` 间接层） | 死链清除，方法名不再误导。注意：**同批次的 `--dart-define` 改造仍未做**，所以前端基址依然靠改 `lib/utils/config.dart` 源码切换 |

### 批次 4 — 清死配置与摆设开关（删除清单 ✅ 已完成，收敛清单未做）

**删除清单 ✅ 全部完成（2026-09-08）**：`backend/api/etc/super.yaml` · `config.yaml:35` 关于 `MOE_SUPER_RPC_ENDPOINT` 的注释（连同 `api.super_rpc_endpoints` / `api.super_rpc_timeout_ms` 整块）· `_runtimeProductionBaseUrl` 间接层 · `api_service.dart:192` 关于 `api_env.json` 的注释 · `assets/pet/config/*.json`（10 个）+ `lib/services/pet_career_config.dart` + `pubspec.yaml` 资源声明 · `.pet_exists_check.txt` · `lib/config/moe_api.json` + `lib/services/remote_api_config_service.dart`。
其中 `backend/.env` 一项经复核为**空指**：磁盘上不存在、git 历史里从未入库（`.gitignore:99-100` 已覆盖），原分析针对的是一个本地未跟踪文件。
连带影响（悬空引用、两个 deploy-ops 真 bug、两份整篇失效文档、codegraph 重生成）见 §9.2。

**收敛清单（未做，属第 2 步调用点迁移）**：20 个 `moe.*_api_in_process` → 1 个（`single_process`），并把 `game` / `notify` / `life` 三个隐藏开关显式化；恒定 `return true` 的 `KratosPK8GoctlRetired()` / `KratosPureHTTPWithoutLegacy()` 直接删除并把调用点固化为 true；`moewiring/config.go` 中约 10 个 yaml 里不存在的 kratos 键，要么补进 `config.yaml`，要么删掉读取逻辑；**新增**：`api.timeout_ms` 只写不读（`config_override.go:68` → `apiconfig.Config.Timeout`，零读者），随 `apiconfig` 一并清除。

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
| 端口注册表强制化：`18888` / `19032` / `6633` / `11434` 要么登记进 `devports/ports.go` + `ports.md`，要么改为从配置读取 |

### 批次 6 — 仓库卫生与文档对齐

- 删除 `moe_ui.xml`、`.cursor/_hero_orig.txt`、根目录 `cover.out`、`duplication-report/`、3 个 `.DS_Store`
- `.gitignore` 补 `/cover.out`（现有第 67 行只覆盖 `backend/cover.out`）、`duplication-report/`、`*.xml` dump、`.DS_Store`
- 处置 `moe_social_backend/` 嵌套仓库：确认后删除，或加入 `.gitignore`
- `tool/` 与 `tools/` 合并为一个目录并加 README 说明分工
- `backend/` 4 份文档（README / LAYOUT / DEPLOY / 架构说明.md）合并
- 修正 §9 表中全部文档漂移项
- **清除 §9.1 的失效启动命令** ✅ **已完成（2026-09-08）**：`ports.md`、`环境配置说明.md`、`cross-platform-dev.md`、`moe-social-runtime.md`、`security-and-stability-backlog.md`、`admin-rpc-runtime-guide.md`、`飞书通知与绑定.md`、`moe-admin.md`、`new-api-kratos.md`、`goctl-generation-hygiene.md`、`kratos-legacy-api-migration.md` 中的 `make rpc` / `make api` / `make rpc-debug` / `make moe-admin-dev` / `make dev` / `make rpc-migrate` / `go run super.go` 已全部改为实际存在的目标（后端唯一入口 `cd backend && make moe-social`），并连带修了 3 个启动脚本与 3 处 Go 运行时提示串（清单见 §9.1）。
  端口表的处理**与本条原计划不同**：实测 `18888` / `19032` / `6633` **没有任何监听者**，只是死函数里的硬编码兜底，因此没有加进「在用端口」表，而是在 `ports.md` 里新开了「已无监听者的端口」表并注明原因；真正需要补的只有 `11434`（n100 上的 Ollama，`config.yaml:97`）和 `3306`（测试库）两个外部依赖。
- `应用配置与全局常量分层约定.md` 补充「环境基址」归属，解决两个 `AppConfig` 同名冲突
- 明确 AI 指令体系优先级（`AGENTS.md` / `.cursor/rules/` / `.qoder/` / `code_review.md` / `CODE_WIKI.md`）

---

## 12. 统一配置加载器（`backend/pkg/conf`）

> **状态：第 1 步已落地（2026-09-08），纯新增，零调用点迁移。** `grep -rn '"backend/pkg/conf"' backend/ --include='*.go'` 目前为空即为证。

### 12.1 要解决的问题

同一份 `backend/config/config.yaml` 被 **20 处**独立打开：19 个 `viper.New()`（`grep -rn 'viper.New()' backend/ --include='*.go'` 共 21 处，减去 `deploy/config/config.go` 里读另一个文件的 2 处）+ `utils.InitConfig()` 的全局 viper 单例，每处都：

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

### 12.4 两个刻意的行为决定

- **`Inference()` 取环境变量的超集**（认全部 4 个 `MOE_LLM_*`）。这意味着 `pkg/moe/runtime` 迁过来之后，`MOE_LLM_BASE_URL` / `MOE_LLM_API_STYLE` / `MOE_LLM_MODEL` **将开始影响 Bot 调度**（此前只有 `MOE_LLM_API_KEY` 生效）。这是有意的收敛，不是回归；已在 `derive.go` 的 `Inference()` 注释里写明。
- **`KratosAdminBaseURL()` 的兜底从 `19032` 改为 `runtime.http_port`。** `moewiring/config.go:184,189` 原先兜底 `http://127.0.0.1:19032`，但 19032 已无任何监听者（见 §9.1 实测结论），照抄等于把「拼出一个打不通的地址」这个行为也一起迁移过来。

### 12.5 第 2 步：调用点迁移顺序

按**消费者数量升序**推进，每步可独立提交、独立验收：

| 序 | 目标 | 消费者 | 备注 |
|----|------|--------|------|
| 1 | `database.*` → `conf.DSN()` | 1（`utils/db.go:96-105`） | 最简单，先跑通链路 |
| 2 | `image.*` / `app_client.*` / `auth.*` / `api.*` / `runtime.*` | 各 1–2 | 顺带删掉 §12.1 表里的驼峰死别名；管理台写回处接 `Reload()` |
| 3 | `llm_inference.*` → `conf.Inference()` | 5 | **收益最大**：一次消掉两条不一致的链，并删除 12 处 `ollama.*` 回退（`config.yaml:126-133` 整段被注释，恒为空） |
| 4 | `moe.*` 调度器 / 模型 | 5 | `pkg/moe/brain/*` 4 处 + `pkg/moe/runtime/post_model.go` |
| 5 | `moe.kratos_*` / `pilot.*` / `production.*` | 多 | **最难**：要吸收 `moeconf.LoadBootstrap()` 的 proto `Bootstrap` 映射，并处置 `moewiring` 里 13 个零调用者的死开关（`SingleProcessEnabled`、`KratosPureEnabled`、`KratosGRPCManaged`、`SuperGrpcRetired`、`KratosPK8GoctlRetired`、`KratosInternalHTTPPort`、`KratosAdminBaseURL` 等） |
| 6 | 删除 `utils.InitConfig()` 全局单例 | 4 个调用者 | `cmd/migrate/main.go:28`、`moeconf/load.go:23`、`moesocial/run_http_only.go:18`、`utils/db.go:35` |

第 5 步完成后，`grep -rn 'viper.New()' backend/ --include='*.go'` 应只剩 `deploy/config/config.go`（Deploy Agent 读的是**另一个** `deploy/config.yaml`，不在本次收敛范围内）。

### 12.6 第 3 步（可选，后续）：拆文件

`config.yaml` → `config.yaml`（入库骨架）+ `env.{local,vps,n100}.yaml` + `secrets.example.yaml` / `secrets.yaml`（gitignore）；加载顺序 base → env → secrets → `MOE_*`；`MOE_ENV` 缺省 `local`。这一步与 §11 批次 2 是同一件事，**必须在凭据轮换之前落地**，否则新密钥会再次写进被跟踪的文件。

> **排期（2026-09-08）**：需求方明确「config 的拆分可以晚一点进行调整」，本步**暂缓**。但上面那句约束不变——它必须排在凭据轮换之前，否则新密钥会重复入库。

---

## 13. 2026-09-08 改动审计

对工作区中尚未提交的全部改动做了一次逐条核实：是否与本文档的判断一致、是否留下悬空引用、是否引入行为变化。

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
| 1 | `config.yaml:35-40` 的 `api.super_rpc_*` 整块零读者，且注释仍在指导运维设置同样无人消费的 `MOE_SUPER_RPC_ENDPOINT` | 整块删除。保留 `moe.pilot.super_rpc_endpoint`（**另一个键**，`moeconf/load.go:62` 真在读） |
| 2 | `api.timeout_ms` **只写不读**（新查明）：`config_override.go:68` 灌进 `apiconfig.Config.Timeout` 后无人消费 | 键暂留（清除属第 2 步的 `apiconfig` 收敛），但注释改为如实标注，并指向真正生效的 `llm_inference.timeout_seconds`；`pkg/conf/config.go` 的 `API.TimeoutMS` 字段同步标注 |
| 3 | `_runtimeProductionBaseUrl` 死间接层 + `initRemoteProductionBaseUrl()` 误导性方法名（§6 / §9 早已登记，本轮才做） | 删字段、更名 `initBaseUrlFromAppConfig()`，同步 `main.dart:195`、`auth_service.dart:93`、`环境配置说明.md:7` |
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

### 13.4 尚未开始、且需要先签字的部分

第 2 步（迁移 20 处调用点到 `pkg/conf`）**未开始**。它是第一步会在真实调用点改变行为，且 §12.4 记录了两个刻意的行为收敛需先确认：

1. `Inference()` 取 `MOE_LLM_*` 环境变量的**超集**（认全部 4 个）。迁移后 `MOE_LLM_BASE_URL` / `API_STYLE` / `MODEL` **将开始影响 Bot 调度**（此前只有 `MOE_LLM_API_KEY` 生效）。
2. `KratosAdminBaseURL()` 兜底从 `19032` 改为 `runtime.http_port`（19032 已无监听者，原兜底会拼出打不通的地址）。

另有两项已知但**本轮刻意未动**：

- `moewiring/api_post.go:63` 读顶层 `hand_draw_require_moderation`，而 `config.yaml` 把它放在 `runtime:` 下 → 该读取恒为 `false`。这是**活的功能 bug**，但修它会改变手绘过审行为，属产品决定，不宜夹在配置治理里悄悄改。
- `pkg/moe/toolaudit` 的 `TestBuildSchemaItemsCoversAllTools`（期望 ≥6 个工具、实得 5）是**既有失败**，已用 `git worktree` 在干净 HEAD 上复现确认与本轮无关。断言和工具列表哪个对属产品判断。

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
```

---

## 相关文档

- [环境配置说明.md](./环境配置说明.md) — 本地 / 线上 API 基址（**§9 指出其已与代码不符，待批次 3 修正**）
- [应用配置与全局常量分层约定.md](./应用配置与全局常量分层约定.md) — Flutter 侧配置分层（**待补环境基址归属**）
- [ports.md](./ports.md) — 本地端口表（**§4.2 指出存在越界硬编码**）
- [kratos-migration-status.md](./kratos-migration-status.md) — Kratos 迁移状态板
- [full-review-2026-09-02.md](./full-review-2026-09-02.md) — 上一次全栈审查快照
- [deploy-platform.md](./deploy-platform.md) — 云平台部署
- [n100-pipeline.md](./n100-pipeline.md) — n100 预发流水线
- [security-and-stability-backlog.md](./security-and-stability-backlog.md) — 安全待办
