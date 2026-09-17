# 配置治理审查（2026-09-08）

> **范围**：`backend/` · `lib/` · `moe-admin/` · `website/` · `deploy/` · `.github/workflows/` · 仓库卫生
> **基线提交**：§0–§12 = `14370f93 feat: 批量更新LLM推理链路与管理台体验`（2026-09-06）；§16–§20 = `bec11b26 feat(life, arena): 落地M0/M1a活世界营地预览功能`（2026-09-09）；§21–§22 = `4f51845e refactor: 移除旧的配置系统，迁移到统一的pkg/conf`（2026-09-09）；§23–§24 = `c083ce8a chore: 完成第九批配置治理整改，统一配置读取入口`（2026-09-11）；**§25 = `a4f476d5 refactor(admin): 移除免鉴权超管创建端点，重构账号初始化逻辑`（2026-09-16）**；**§26 = `54c5aa45 refactor(llm): LLM raw 透传端点迁移到 Kratos 原生路由并补全适配层`（2026-09-17）+ 本批工作区改动**；**§27 = 与 §26 同一基线 `54c5aa45` + 本批工作区改动（#41/#42/#48/#49 尚未提交）**；**§28 = 与 §27 同一基线 + 工作区改动（#19 尚未提交）**；**§29 = 与 §28 同一基线 + 工作区改动（#43 尚未提交）**
> **提交状态**：第一批（§13）= `8037287e`、第二批（§14）= `3ebcf62d`、第三批（§15）= `1d5a45ac`；第四至第七批（§16 第2步调用点迁移 · §17 第五批冗余收拢 · §19 批6a+序6 · §20 序2）合并入库于 `4f51845e`（已实测确认：`conf.DSN()` 由该提交引入，而 `bec11b26` 对配置治理零改动）；第八批（§21）、第九批（§22）与第十批（§23）合并入库于 `c083ce8a`；**第十一批（§24）= `e1f03a86`**（早先记为「未提交」，已入库）；第十二批的 `life_items` 去重 = `0459e256`；**第十三批的 #39/#40 = `54c5aa45`，#41/#48/#49 仍在工作区**（5 改 + 1 删：`internal/server/auth.go`、`auth_test.go`、`transport/oauth.go`、`transport/sse.go`、`internal/biz/companion/engine_test.go`，删 `transport/bind.go`）；**第十四批（§27 / #42）全部在工作区**：43 文件 +1941/−8868，其中 5 个整文件删除（`apicomm/admin_memory.go`、`apicomm/local_models.go`、`apicomm/local_models_test.go`、`transport/bind.go`、`_probe/mint/main.go`）。**第十五批（§28 / #19）全部在工作区**：7 文件纯改、零删除（`pkg/conf/config.go`、`pkg/conf/derive.go`、`pkg/conf/conf_test.go`、`config/config.yaml`、`moewiring/api_life.go`、`moewiring/api_game.go`、`internal/service/game/game.go`）。**第十六批（§29 / #43）全部在工作区**：8 文件改 + 1 文件新增、零删除（改：`internal/service/companion/companion_api.go`、`deploy/config/config.go`、`internal/server/protohttp/adminapp/adminapp.go`、`lib/pages/checkin/checkin_page.dart`、`pkg/conf/derive.go`、`utils/admin_runtime_config.go`、`pkg/moe/core/tier.go`、`pkg/moe/toolaudit/record_test.go`、`internal/biz/appcfg/public.go`、`docs/dev/Moe-Intelligence-Stack-v1.md`；新增：`internal/biz/appcfg/public_test.go`）。
> **性质**：§0–§12 是**只读审查**，所有结论均给出 `文件:行号` 证据，可按附录 A 的命令复核。§13–§29 记录审查之后**已落地的十六批改动**（含改动内容与验证结果），性质是变更记录而非审查。**§25–§27 已超出「配置治理」范畴**：这几批是在推进配置项时顺带挖出的**活 bug 与安全缺陷**（免鉴权端点、门禁失效、鉴权白名单、开放重定向、假成功信封），按需求方「先修活 bug，再推配置项」的决定优先处置；**§28 起回到配置项本身**。
> **有效性**：本文是**绑定基线提交 `14370f93` 的快照**（依 `docs/README.md` 文档维护约定第 3 条）。§11 各批次整改落地后，对应章节即失效，应**直接删除该章节**而非保留 archive stub。所有行号以该基线为准，后续提交可能使其偏移。
> ⚠️ **行号提醒**：前十六批改动已使 §0–§12 的部分行号失效（尤其 `moewiring/config.go`——该文件从 191 行降到 **48** 行，原 `:62-190` 区间的引用全部作废；§16 又让 `utils/db.go` 原 `:96-105` 塌缩为 `:96` 一行；§22 让 `runtime/config_load.go` 从 87 行降到 37 行，并删掉了 `internal/adapter/moeconfig/` 整个目录；§24 摘掉了 `pkg/conf/config.go` 里 `MoeProduction` 的 4 个字段、并重写了 `utils/admin_runtime_config.go` 的写回实现；§25 删掉了免鉴权的超管创建端点及其路由；§26 把 `internal/server/auth.go` 的 `publicPaths` 单表拆成读/写两张表并删了 10 条死条目——**该文件所有行号引用一律作废**，`transport/bind.go` 也已整文件删除；**§27 删掉 21 个操作，`backend/openapi.yaml` −983 行——该文件所有行号引用一律作废**，同样作废的还有 `legacy/types/types.go`（删 9 个类型）、四个 proto 及其 `.pb.go`（llm / admin / companion / platform）、`apiconfig/config.go`、`wiring/config_override.go`、`pkg/conf/config.go`、`config/config.yaml`（`local_models:` 段消失，其后行号整体前移）、`api/etc/moe.yaml`、`biz/llm/platform_common.go`（原 `:126-148` 两个 501 桩已删）、`lib/services/companion_service.dart`；`apicomm/local_models.go` 与其测试整文件删除；**§28 删掉了 `moewiring/api_life.go:8` 的 `livingWorldIntervalSeconds` 常量并重写了该文件的装配段——§16.4 对它的引用（含那张四行副本表的第 3 行）一律作废**，同时作废的还有 `pkg/conf/derive.go`（`:31-36` 插入新常量、`:285-313` 插入两个新函数，其后行号整体后移）、`pkg/conf/config.go` 与 `config/config.yaml`（各插入 3 个新键 / 5 行，其后行号再次后移）、`pkg/conf/conf_test.go`、`internal/service/game/game.go`、`moewiring/api_game.go`；**§29 摘掉了 `pkg/moe/core/tier.go` 里三个幽灵工具名并重写了 `AllowsTool`——它从 `:32-45` 移到 `:38-51`，§25.7 对 `tier.go:39,43` 的引用与 §23 第 29 行对 `tier.go:32-45` 的引用一律作废**；同批 `pkg/moe/toolaudit/record_test.go` 追加 37 行、`pkg/conf/derive.go` 因导出 `TrimURL` 再次后移（现 `:382-402`）、`utils/admin_runtime_config.go` 删掉私有 `trimURL` 并把 6 个调用点改指 `conf.TrimURL`、`internal/biz/appcfg/public.go` 重写并新增同目录 `public_test.go`、`companion_api.go`（3 行）/ `deploy/config/config.go`（3 行）/ `adminapp.go`（2 行）/ `checkin_page.dart`（1 行）修乱码、`docs/dev/Moe-Intelligence-Stack-v1.md` 的 §2 档位表与 §4 工具清单已重写。**§23 第 29 行引的 `config.yaml:184` 现为 `:171`**（`local_models` 整块 13 行被删所致，是上移不是下移））。凡被 §13–§29 就地更新过的条目，以更新后的文字为准；未更新的条目按基线行号读。
> **前提说明**：当前仓库内的第三方密钥为**开发期临时凭据，正式版会整体更换**。因此本文的重点不是「密钥泄露应急」，而是**为什么结构上会导致密钥只能写在这里**——结构不改，换完新密钥仍会回到同一状态。

---

## 0. 结论速览

一句话：**项目有 5 个运行环境，但没有环境抽象层**，于是每个环境的值都被硬写进各处被 git 跟踪的文件里，靠人工同步。

| # | 问题 | 严重度 | 关键证据 | 整改批次 |
|---|------|--------|----------|----------|
| 1 | 明文凭据在被跟踪的 `config.yaml` 内 | P0 | `backend/config/config.yaml:11,23,28,51,81,256` | 批次 1 |
| 2 | Android release 签名口令有明文 fallback | P0 | `android/app/build.gradle.kts:27,29` | 批次 1 |
| 3 | 同一 API 地址有 14 处运行时副本 | P1 | 见 §4.1 表 | 批次 3 |
| 4 | 改 yaml 可能不生效（Go 硬编码短路 / 键名写错） | P1 → **已完成** | ✅ Go 硬编码短路那一半已消除（`moewiring/config.go` 那族过渡开关全删，见 §5.3）；键名写错那一半已修（`admin_runtime_config.go` 写蛇形键、`hand_draw_require_moderation` 补 `runtime.` 前缀，见 §5.5 / §14.3）；~~剩 `config_override.go:73,97` 的驼峰死别名~~ → **批6a 已删完**（见 §19.1，实测比 §17.4 宣布的多 11 处） | 第 2 步 ✅ |
| 5 | 「SSOT」声明与实际真源不符（Agora 段） | P1 | `api/etc/moe.yaml:11` vs `config.yaml` 无该段 | 批次 2 |
| 6 | 端口 SSOT 被越界硬编码 | P2 | ✅ **已消除**：`18888` / `19032` 的硬编码兜底随死函数删除，可执行路径里已无这两个无监听者的端口（见 §4.2、§15.4）。**剩** `6633` / `11434` 未登记 | 批次 5 |
| 7 | 死配置 / 摆设开关制造噪音 | P2 → **已完成** | ✅ 零调用方那一类已清空（`api.timeout_ms` 链、15 个 Kratos 过渡开关、`wireKratosNotes` 链，见 §15.2）；`moe.*_api_in_process` 经实测**不是死配置**（40 处活调用点），已于第九批收敛到 `conf.DomainInProcess()`（见 §22.2）。原见 §6 表 | 批次 4 ✅ |
| 8 | 切环境 = 改源码 + 重启 + 提交 | P1 | `lib/utils/config.dart:16`、提交 `96d7a612` | 批次 3 |
| 9 | 服务器配置与仓库配置已永久分叉 | P1 | `backend/scripts/vps-switch-companion-model.sh` | 批次 5 |
| 10 | 4 套部署链互不知情，两条会互删产物 | P1 | `sync-lan.ps1:12,24` vs `n100-deploy.yml:57` | 批次 5 |
| 11 | 调试产物被提交进仓库 | P3 | `moe_ui.xml`、`cover.out`、`duplication-report/` | 批次 6 |
| 12 | 文档描述的配置机制与代码不符 | P2 | 见 §9 表 | 批次 6 |
| 13 | ~~本机拉起后端默认直连生产 MySQL root~~ **已澄清：该库是测试库** | ~~P0~~ → 非问题 | 需求方确认 `47.106.175.49` 为**测试库**，开发机直连属预期便利；凭据入库的问题归入第 1 行 | 不整改 |
| 14 | 文档教的启动命令已整体失效（`make rpc` / `go run super.go`） | P1 → **已完成** | `backend/rpc/` 目录不存在；见 §9.1（2026-09-08 已清理脚本、Go 提示串与 11 份文档） | 批次 6 ✅ |
| **15** | **同一份 `config.yaml` 被 20 处独立打开，回退链各自实现** | P1 → **已完成** | ✅ **第九批闭环**（见 §22）：有效收敛率 **100%**（105 键的真读者归零），`viper.New()` 20 → **2**（第十一批删掉第 3 处后，只剩 `deploy/config/config.go` 那两处，读的是另一个文件、本就不在收敛范围内）且逐个有据，自带 `searchDirs` 的文件 10 → **0**，`pkg/conf` 反向依赖 0 → **49** 个文件。原见 §12 | 批次 2 ✅ |
| **16** | **已发布的 release APK 连的是开发机局域网 IP，且 CI 全绿、Release 正常发布** | **P0（实际已发生）** | `flutter-release.yml` 不带 `--dart-define` + `config.dart` 的 `isProduction` 硬编码 `false` + `developmentUrl = 192.168.124.36`；见 §14.1 | ✅ 已闭环：`flutter-release.yml` 第 7 步发布前断言 + `config_test.dart` 内网地址断言（**不改 `isProduction` 语义**，因与三条既有规则冲突，方案取舍见 §14.1） |
| **17** | **`life_items` 每次进程启动插入 6 条重复道具**（种子 `OnConflict{DoNothing}` 永不触发） | **P2（数据在持续膨胀）** | `internal/data/life/store.go:259` 的 `DoNothing` 需要唯一键冲突，但 `model/life_item.go:8` 的 `Name` **没有 `uniqueIndex`**；实测两次启动之间行数 582 → 588；第十一批（§24.9）真实启动再测一次，**594 → 600**，仍在按每次启动 +6 累积。差分启动顺带照出，见 §22.7 | ✅ **已修复（第十二批）**：`Name` 加 `uniqueIndex:idx_life_items_name` 让 DoNothing 生效；迁移框架新增 BeforeMigrate 钩子，建索引前先合并重复行（含库存外键重指向），共享测试库实测 **600 → 6 行**、悬空引用 0。见 §22.7 ↪️ |
| **18** | **全仓没有任何文档提到 `pkg/conf`**，24 处文档陈述已失真（其中 1 处在 `alwaysApply: true` 的工程规则 SSOT 里） | **P1** | `.cursor/rules/moe-social-engineering.mdc:336` 教人用 `-conf ./config` 启动，而 `cmd/moe-social/main.go:18` 只有 `-f`，照做必报 `flag provided but not defined: -conf`；其余 23 处见 §23 | 批次 6（文档对齐）→ §23 |
| **19** | **管理台点一次「保存」会销毁 `config.yaml` 全部 79 行注释**，并静默把 3 个 float 降级成 int | **P1（破坏性，写在 HEAD 上就有）** | 旧 `ApplyRuntimeConfigPatch` 走 `viper.Set` + `WriteConfig()`，实测真实文件 10073→**4416** 字节、265→**154** 行、注释 79→**0** 行；被抹掉的注释里有只此一处的运维知识（本地地址备选 `:133`、CDN 回退语义 `:164`、被注释掉的 `ollama:` 段 `:122-126`、本地数据库段 `:257-265`）。见 §24.4 | 批次 11 ✅ → §24.4 |
| **20** | **配置的读路径与写路径对「哪个文件是权威」答案不一致**，且 `Reload()` 有一个跨整次读盘的未加载窗口 | **P1** | 读路径 `ReadRuntimeConfig` → `conf.Reload()` → `current.path` 尊重 `-f`；写路径 `resolveUnifiedConfigPath()` 从不查 `conf.Path()`，只试 3 个 cwd 硬编码候选，写完还 `conf.LoadFile(那个路径)` 把整个进程的配置源劫持走。`Reload()` 旧实现先置 `current = nil` 再读盘，窗口内并发 `Get()` 落到包级 `searchDirs` 而非 `-f`，实测 **0.25 秒内 459501 次错值读取**（cwd 下没有 `config/` 时读到零值 `Config`：`DSN()` 空连接串、`AuthAccessSecret()` 空密钥）。见 §24.2 / §24.3 | 批次 11 ✅ → §24.2–§24.3 |
| **21** | **`POST /api/admin/moe/bootstrap` 让任何人无需登录就能把自己创建成超管** | **P0（免鉴权提权）** | 该端点在 `publicWritePrefixes` 之外的旧 `publicPaths` 里被前缀放行，且自身不校验任何凭据；实测裸 `curl` 即可拿到 `super_admin` token。见 §25.2 | ✅ 批次 12：迁移时种账号 + 删端点（§25.3） |
| **22** | **`CGO_ENABLED=0` 让全仓 DB 用例静默 `t.Skip`，`make check` 全绿但什么都没验** | **P1（门禁失效）** | 本机 `go env CGO_ENABLED` 持久为 0，gorm sqlite 依赖 cgo；被它藏住的有 3 条真实失败用例。见 §25.4 / §25.5 | ✅ 批次 12：`make test` 写死 `CGO_ENABLED=1` + `utils/cgo_canary_test.go` 哨兵 |
| **23** | **缺 HTTP 适配层的 RPC 不报 404、不报编译错，被内嵌 `Unimplemented*Server` 桩答成永久 501** | **P1（一类，非一处）** | LLM raw 透传端点两条、`/api/admin/moe/brain/pipeline/stream` 等；`prototest.AssertRPCsAdapted` 之后这类漏洞在测试期就会红。见 §26.1 | ✅ 批次 13：补适配层 + 落门禁 |
| **24** | **鉴权白名单不分 HTTP 方法，前缀命中即一律放行** → `POST /api/llm/models/delete`、`POST /api/llm/models/download`、`DELETE /api/images/{filename}` 三条写接口免鉴权 | **P0（免鉴权写）** | 旧 `publicPaths` 32 条一视同仁；实测三条写路由在无任何凭据时穿透过滤器。拆成读/写两张表后写路由恢复 401，读路由（含终端模式的 `/api/llm/models/raw`）逐条保住。见 §26.2 | ✅ 批次 13：`publicReadPrefixes` / `publicWritePrefixes` 分表 |
| **25** | **三个 GET 路由用 body 解码器 `ctx.Bind`，永远 400 `unregister Content-Type: `**；且 `make check` 每天 9 小时必红 | **P1 + 门禁失效** | 前者：`transport/oauth.go` 两个回调 + `transport/sse.go`，而 legacy `types.go` 只有 `form:` tag，`BindQuery` 同样填不进去（见 §26.3）；后者：`TestPushProactiveOnlyAfterInactivityCooldown` 用 `defaultProfile()` 的 22:30–07:30 UTC 免打扰窗口，而 `pushProactive` 读 `time.Now().UTC()`，实测 UTC 02:31 红、17:07 绿（见 §26.4）。修 #25b 时顺带照出**免打扰早退分支此前零覆盖**（变异 MC 改坏实现全仓无一用例变红） | ✅ 批次 13：三条改读 query + 钉死时钟 + 补 `TestPushProactiveSkipsInsideQuietHours` |
| **26** | **OAuth `state` 同时充当回跳地址，校验只看 scheme 不看 host** → 免鉴权 302 可把**真实授权码**送到任意站点，构成账号接管；`state` 被这样消耗掉也意味着整条 OAuth 流程**零 CSRF 防护** | **P0** | `utils/feishu_oauth_redirect.go:11-51` 的 `isAllowedReturnURL` 对 `http`/`https` 直接 `return true`；纯函数探针实测 `state="https://evil.example/steal"` → `"https://evil.example/steal?feishu_code=CODE-ABC"`（wechat 同构）；链条第一环 `q.Set("state", state)` 原样透传，而 `authorize-url` 本身免鉴权。见 §26.5 | ⛔ **登记不修**：早于本批（wechat 一直可达），回退飞书白名单会重新打断飞书登录；host 白名单是策略决定，与需求方「多机开发 / 隧道来回切」的约束冲突 |
| **27** | **`POST /api/user/reset-password` 不校验任何验证码，仅凭 email 就能改掉该账号密码** | **P0（账号接管）** | `ResetPasswordReq` 里连 `code` 字段都没有；`publicWritePrefixes` 放行三条找回密码路由，其中两条后端未实现（404），第三条实现完整且无校验。见 §26.5 | ⛔ **登记不修（需求方决定「这个暂时不做处理」）**：保持原样放行，不要顺手改它的语义 |
| **28** | **业务失败被当载荷返回，客户端只校验外层信封 → 弹绿色成功提示却什么都没做** | **P1（对用户撒谎，比报错更坏）** | `platform_llm.go:37` 是 `return platformWriteToBaseResp(result), nil`，**error 恒为 nil**；真机实测 `POST /api/llm/agents` 回 `{"code":200,"data":{"code":501,"message":"未实现"},"message":"操作成功","success":true}`。Dart 侧只看外层：`api_service.dart:483,492,498` + `api_response.dart:7-13`（`code==200` 属白名单）→ `llm_api_service.dart:68` 判成功 → `chat_page.dart:817` 弹 `'系统提示词已更新并同步到服务器模型'`。见 §27.5 | #51（**原记录「每次必弹红色错误」是错的，已改写**）；`platformWriteToBaseResp` 目前仅 1 个调用点，但同形适配方法会继承这个假成功 |
| **29** | **两个引擎的世界节奏是编译期常量，调一次要重新构建部署整个后端**；且 `45` 这个数在仓里有两份副本，把下游的兜底守卫顶成了死代码 | P2 | §16.4 登记的四处硬编码 + 两处可配；生效的两处是 `moewiring/api_life.go:8` 的 `livingWorldIntervalSeconds = 5*60`，与 `service/game/game.go` 里另一个 `45*time.Second`（与 `gamebiz.defaultWorldTickInterval` 同值，导致 `world_runner.go:20` 的 `interval <= 0` 永不可达）。见 §28 | ✅ 批次 15：新增 `moe.life_tick_seconds` / `life_flush_seconds` / `world_tick_seconds`，真机双跑实测生效（300/300 vs 30/45）。**两处 biz 层缺省值故意保留**，理由见 §28.2 / §28.3 |
| **30** | **同一件事在仓里有三份各执一词的描述，分叉时全都不报错**：URL 规范化有三份逐字节相同的副本、档位闸放行三个注册表里不存在的工具名、文档工具清单列了五个不存在的工具 | P2 | ① `pkg/conf/derive.go` · `utils/admin_runtime_config.go` · `internal/biz/appcfg/public.go` 三份「TrimSpace + 去尾斜杠」逐字节相同，规范化的是同一批 `public_base_url`；② `tier.go` 的 `AllowsTool` 放行 `memory_search`/`memory_get`/`memory_save`，而注册表只有 5 项；③ `Moe-Intelligence-Stack-v1.md` §4 列 8 个工具、§25.7 只登记 5 处乱码（实测 9 处，含 2 处终端用户可见）。见 §29 | ✅ 批次 16：三份副本全部委托到导出的 `conf.TrimURL`（**第四份 `media/image.go:66` 兜底值不同，刻意不并**，归 #44）；摘掉三个幽灵工具名并新增回归钉，变异证明**旧套件对此失明**；9 处乱码全修，恢复结果与仓内自带的干净同胞逐字节相同；真机实测 `public_api_base_url: "/"` 由「200 + 空基址」变为 **404**（本批唯一行为变更）。#43 仅剩 #16（gradle 口令）未做 |

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

> **状态：已修复。** 当前工作区 `admin_runtime_config.go:327-344` 写的是蛇形键（第十一批重写写回实现后从 `:99-109` 移到这里），并留了注释说明原因：
>
> ```go
> // 键名必须是 config.yaml 实际使用的蛇形键；写成 Image.PublicBaseUrl 会被小写化为
> // 无下划线的 publicbaseurl 死键，运行时优先读 public_base_url，改动静默丢失。
> var edits []yamlEdit
> if patch.ImagePublicBaseUrl != nil {
> 	edits = append(edits, yamlEdit{"image.public_base_url", trimURL(*patch.ImagePublicBaseUrl)})
> }
> if patch.ImageLocalDir != nil {
> 	edits = append(edits, yamlEdit{"image.local_dir", strings.TrimSpace(*patch.ImageLocalDir)})
> }
> if patch.ImageMaxBytes != nil {
> 	edits = append(edits, yamlEdit{"image.max_bytes", *patch.ImageMaxBytes})
> }
> ```
>
> ↪️ 第十一批（§24.4）把写回机制从 `viper.Set` + `WriteConfig()` 换成 `yaml.v3` 定点改行，
> 上面三行的**形态**因此从 `v.Set(k, v)` 变成 `edits = append(edits, yamlEdit{k, v})`，
> 但「键名必须是蛇形」这条约束一字未变 —— 现在它由 `locateYAMLNode` 沿点路径在真实文档里
> 逐段查键来强制，写错键名会直接**报错**（「配置文件里不存在键 …」）而不是静默生成死键。
> 这比旧实现更强：旧的 `v.Set` 对任何键名都照单全收。
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

> ⛔ **本批次的核心动作（按环境拆 config）已于 2026-09-16 被需求方否决，不要再执行。** 原话、理由与「不要再提」的约定见 §12.6 的 ⛔ 块，摘要见 §25.8。下表**保留原样**作为决策痕迹，但逐行的现状是：
>
> | 行 | 现状 |
> |---|---|
> | `config.yaml` → `config.example.yaml` + gitignore | **挂起**。前提是先有 `secrets.yaml` 可拆出去；拆分取消了，这行没有落点 |
> | per-env 覆盖片段 / 内网 IP 不得入库 | **作废**。per-env 就是被否决的那件事；IP 配置需求方已明确「暂时都在 `lib/utils/config.dart` 里维护，这样比较清晰」 |
> | ~~`admin_runtime_config.go:100` 键名~~ | 早已完成（§5.5），与本批次无关 |
> | `Agora` 段并入 `config.yaml` 或明确 `api/etc/moe.yaml` 职责边界 | **仍然有效**。这是 SSOT 归并问题，跟拆不拆文件无关，随时可做 |
> | 「轮换凭据要在批次 2 落地后再换」 | **前置条件已消失**。需求方已确认现有第三方密钥与数据库口令都是开发期临时值、正式版整体更换，后端连的也是测试库；既然不再拆文件，轮换就不必再等什么，按正式版发布节奏走即可 |

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

> **计数修正（2026-09-08 第三批后实测）**：原文写「20 处 = 19 个 `viper.New()` + `utils.InitConfig()`」，多算了 1 处。实测 `grep -rn 'viper.New()' backend/ --include='*.go'` 共 **22** 处命中，需排除 4 处：`deploy/config/config.go` 的 2 处（读的是**另一个** `deploy/config.yaml`）、`pkg/conf/load.go:201` 的 1 处（这是**新加载器自己**，不是遗留读取点）、`pkg/conf/config.go:3` 的 1 处（注释文字）。余下 18 处才是遗留读取点。
> 第三批**没有改变这个计数**：已核对 HEAD，被删函数所在的 `moewiring/config.go` 在改动前后都只有 1 处 `viper.New()`（在 `moeViper()` 里），被整文件删除的 `wire_mode.go` 是 0 处。
> **文件数修正（2026-09-09 复核实测）**：原文写「18 处分布在 16 个文件」。18 处正确，但 16 个文件**与 18 处不同口径** —— 既然把 `deploy/config/config.go` 的 2 处从站点数里排除了，就必须把这个文件也从文件数里排除，正确值是 **15 个文件**（raw grep 22 处命中 / 16 个文件，减 `deploy/config/config.go` 后为 18 处 / 15 个文件）。这与 §15.5 记录的是同一类错误：**分子与分母必须在同一口径上**。
> **第五批后计数（2026-09-09 实测）**：raw grep 从 22 降到 **21** 处命中 —— `moeconf/load.go:27` 随整包删除消失。排除项不变（仍是 `deploy/config/config.go` 2 处 + `pkg/conf/load.go:201` + `pkg/conf/config.go:3` 注释），故遗留站点为 **17 处 / 14 文件**，总独立打开点 **18 处**。同时 `utils.InitConfig()` 的**生产**调用方从 4 个降到 **3 个**（`cmd/migrate/main.go:28`、`moesocial/run_http_only.go:18`、`utils/db.go:36`；`moeconf/load.go:23` 已随包删除，另有 `utils/feishu_test.go:57` 一处测试调用不计入）。这是 §12.5 序 6 的第一次实际缩减。

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

### 12.4 刻意的行为决定（原 2 项 → 现 0 项待签字）

- ~~**`Inference()` 取环境变量的超集**（认全部 4 个 `MOE_LLM_*`）。这意味着 `pkg/moe/runtime` 迁过来之后，`MOE_LLM_BASE_URL` / `MOE_LLM_API_STYLE` / `MOE_LLM_MODEL` **将开始影响 Bot 调度**（此前只有 `MOE_LLM_API_KEY` 生效）。这是有意的收敛，不是回归；已在 `derive.go` 的 `Inference()` 注释里写明。~~
  > ✅ **第九批已落地，签字项用证据结掉而非上报**（见 §22.4）：实测这三个变量的**唯一设置处**是 `backend/docker-compose.binary.yml:10-12`，默认值全是空串 `${VAR:-}`。只有运维显式去设一个「其唯一用途就是把 LLM 端点搬走」的变量时该行为才触发，而那时让 Bot 调度继续连旧端点恰恰就是 §12.1 要消灭的缺陷本身 —— **不收敛才是 bug**。理由已逐字写进 `derive.go` 的 `ResolveInference()` 文档注释（`Inference()` 现在是它的解析版）。
- ~~**`KratosAdminBaseURL()` 的兜底从 `19032` 改为 `runtime.http_port`。**~~ **❌ 已作废（第三批）**：该函数连同它的两处 `19032` 兜底已被整体删除（零外部调用方，见 §15.2 B 组），迁移目标不存在了。因此第 2 步**只剩 1 项需要签字的行为变更**（上面那条 `Inference()` 取环境变量超集）—— 该项已于第九批结掉，本节现无待签字项。
  > **歧义澄清（2026-09-09 第五批）**：上一句删掉的是 **`moewiring` 的遗留函数**。`pkg/conf/derive.go:250` 那个**同名新方法当时并没有删**，它带着「兜底改为 `runtime.http_port`」的注释一直留到第五批——实测 `conf.KratosAdminBaseURL()` 形式的外部调用方为 **0**，即它是一个**生下来就没有调用方的迁移目标**（目标已在第三批消失）。第五批连同另外 3 个 `Kratos*Enabled()` 方法、9 个 `Kratos*` 类型化字段一并删除。<br>⚠️ 同时删掉的还有它的专属用例 `TestKratosGates`（原 `conf_test.go:419-438`，注释自称「复现 moewiring 的总闸语义」）——**这是一个「用测试把死代码保住」的实例**：用例断言的是已删除函数的行为，所以只要它在，那 4 个零调用方的函数就删不掉、`go test` 也永远是绿的。§16.2 的教训是「测试通过 ≠ 已接线」，这一条是它的镜像：**测试通过也可能只是死代码有人看守**。

### 12.5 第 2 步：调用点迁移顺序

按**消费者数量升序**推进，每步可独立提交、独立验收：

> ✅ **六序已全部完成**：序1（§16.1）· 序2（§20）· 序2.5（§21）· 序6（§19.2）· 序3 + 序4 + 序5（§22，一次做完）。下表保留为**历史评估记录**，其中三处「原评估严重低估」的更正就地写在各行的备注里；行内所有 ❌ / 待办均已闭环。

| 序 | 目标 | 消费者 | 备注 |
|----|------|--------|------|
| 1 | `database.*` → `conf.DSN()` | 1（`utils/db.go:96`，原 `:96-105`） | ✅ **已完成（2026-09-09，见 §16.1）**。运行时验证过新旧 DSN 逐字节相同、两侧读到同一个 `config.yaml` |
| 2 | `image.*` / `app_client.*` / `auth.*` / `api.*` / `runtime.*` | 各 1–2 | ✅ **驼峰死别名已于第五批删完**（见 §17.4）：`config_override.go` 里 **11 处** `image.*` 多键并查折叠为单键直读、1 处不可达的 `Image.OSS.ProxyViaAPI` else-if 删除，`firstNonEmptyString` / `firstPositiveInt64` 两个辅助函数随之整体移除（实测 141 行 → 111 行）。**本步只剩**：管理台写回处（`utils/admin_runtime_config.go`）接 `Reload()` |
| 3 | `llm_inference.*` → `conf.Inference()` | ~~5~~ **24 处读取 / 7 文件** | ✅ **第九批已完成（见 §22）**：`moeconfig` 整目录删除、`readInferenceFragment()` 删除、`apicomm.ContextLimitFromViper` / `brain.defaultContextLimit` / `runtime.LoadInferenceFromViper` 三个重复读者删除；新增 `ResolveInference()`（原值）与 `Inference()`（解析版）之分。<br>**收益最大**：一次消掉两条不一致的链。⚠️ **原评估「5」与序 6 的「4 个调用者」是同一类低估**（数的是 `viper.New()` 站点，不是读取点）——这是该错误第三次出现。实测 13 个文件提及 `llm_inference.`，其中 4 个只是注释或错误消息字符串（`apicomm/llm_inference_client.go`、`protohttp/moe_extended.go`、`runtime/generate.go`、`runtime/host_metrics.go`），正是 §13.3 的「命中≠消费」；真读取为 24 处 / 7 文件（`moeconfig/inference.go` 10、`wiring/config_override.go` 5、`runtime/config_load.go` 5、`apicomm/inference_props.go` 1、`brain/prompt_memory.go` 1、`brain/topic_analyze.go` 1、`runtime/post_model.go` 1）。<br>✅ **`ollama.*` 回退已于第五批全部删除**（原写 12 处，实测 **15 处**，见 §17.3），本步剩余工作量随之缩小 |
| 4 | `moe.*` 调度器 / 模型 | 5 | ✅ **第九批已完成（见 §22）**：`brain/{topic_analyze,prompt_memory,dream_schedule,refine}.go` + `runtime/post_model.go` 各自的本地 viper 读取函数全部删除，改调 `conf.TopicAnalyzeModel()` / `ContextTokens()` / `DreamScheduler()` / `BotPostModelConfigured()`。顺带修掉一处 §12.1 类缺陷：`runtime` 与 `brain` 各有一个**同名** `loadBotPostModelFromViper`，回退链还不一致（runtime 认 `chat_model`，brain 不认），现已合一 |
| 5 | ~~`moe.kratos_*` / `pilot.*`~~ / `production.*` | ~~多~~ **只剩端口口径** | 原评为「最难」：要吸收 `moeconf.LoadBootstrap()` 的 proto `Bootstrap` 映射，并处置 `moewiring` 里 13 个零调用者的死开关。**第三批已把死开关全部删掉（实测 15 个）**，`moewiring` 只剩 8 个函数、全是活的 `*_api_in_process` 装配开关。<br>✅ **第五批已把剩余部分做完**（见 §17.2）：`moeconf` 整包删除，`MoePilot` + 9 个 `Kratos*` 字段 + 4 个 `Kratos*` 派生方法一并移除，`config.yaml` 的 `moe.kratos_pure_enabled` / `moe.kratos_admin_base_url` 两键删除，孤立的 `internal/conf/moe/v1`（proto + 生成物）与 `gen-moe-conf` 生成链退役。~~**本步现在只剩 `production.*`**：`external_http_port`（字符串 "8888"）与 `runtime.http_port`（int）表达同一件事，读取点是 `moesocial/startupconfig.go:70-79` 的回退链 + `derive.go:124 HTTPPort()`~~ → ✅ **已闭环**：`production.external_http_port` 由**序2**收掉（见 §18.3 第三版记账更正），其余 `moe.*` 由**第九批**收掉（19 个 `*_api_in_process` + `life_engine_enabled` + 两个调度器开关与 tick + `bot_smart_*` 一对，共 30 键，见 §22.2）。`moewiring/config.go` 从 82 行降到 48 行，只剩 4 个供 `wiring/wire_*.go` 20 处调用的薄封装 |
| 6 | 删除 `utils.InitConfig()` 全局单例 | ~~4 个调用者~~ **50 处读取 / 16 个文件** | ⚠️ **原评估严重低估（2026-09-09 实测纠正）**：「4 个调用者」数的只是**调用 `InitConfig()` 的地方**（`cmd/migrate/main.go:28`、~~`moeconf/load.go:23`~~、`moesocial/run_http_only.go:18`、`utils/db.go:35`；第五批删掉 `moeconf` 后**只剩 3 个生产调用方**），但真正**依赖它已被调用**的是全局 viper 单例的 **50 处读取点，分布在 16 个文件**：`utils/` 38 处 / 12 文件（`feishu.go` 6、`feishu_oauth.go` 6、`wechat_oauth.go` 5、`private_message.go` 5、`feishu_contact.go` 4、`feishu_public_config.go` 3、`auth_jwt_config.go` 2、`admin_seed.go` 2、`admin_jwt.go` 2、三个 redirect/flow 各 1），`internal/` 12 处 / 4 文件（`service/user/user_temp_mail.go` 5、`biz/user/oauth_wechat.go` 4、`biz/user/oauth_feishu.go` 2、`biz/admin/dashboard.go` 1）。按配置段分：`feishu.*` 23、`wechat.*` 8、`private_message.*` 5、`temp_mail.*` 4、`admin.*` 4、`auth.*` 3、`api.*` 1。<br>✅ **好消息：类型化侧已完全就绪** —— 实测这 50 处读取涉及 **32 个唯一键，`pkg/conf` 已全部建模**（含嵌套的 `Admin.Bootstrap.Username/Password`，`config.go:71-73`）。所以本步**不缺任何结构体，纯属机械改写 50 处读取点**。<br>✅ **「与 `moeconf` 删除合并做」的建议已于第五批执行**（见 §17.1）：`LoadBootstrap` 的注释写明它「先 InitConfig，再映射 moe 段」，两者本就是同一条链，现已一起收掉 |

~~第 5 步完成后，`grep -rn 'viper.New()' backend/ --include='*.go'` 应只剩 `deploy/config/config.go`（Deploy Agent 读的是**另一个** `deploy/config.yaml`，不在本次收敛范围内）。~~
> ✅ **实测结果（第九批后）：3 处 / 2 个文件**，比上面这句预测多 1 个文件：`deploy/config/config.go:43,50`（两处，Deploy Agent 读的是**另一个** `deploy/config.yaml`，自带 base+override 合并逻辑，不在收敛范围内，且正是 §12.6 拆文件时要抄的样板）+ `utils/admin_runtime_config.go:56`（「读—改—写」的写路径；`pkg/conf` 没有 setter，而它写完后追加了 `conf.LoadFile(path)`，进程内缓存因此跟得上文件 —— 见 §18.3 障碍 1 的既定处置）。基线 20 → 序6 后 19 → 序2 后 16 → 第九批后 3。
>
> ✅✅ **第十一批后：2 处 / 1 个文件 —— 上面那句被划掉的预测至此逐字兑现**。§24.4 把 `utils/admin_runtime_config.go` 的 `newUnifiedConfigViper()` 整个删掉了：写回不再经过 viper，改成用 `yaml.v3` 取行列号、在原始字节上定点改行。连带消失的还有那个「`pkg/conf` 没有 setter，所以写路径必须自己开一个 viper」的绕法 —— 写路径现在的收尾仍是一次 `conf.LoadFile(path)`，但读改写的三步都不再需要第二个配置源。剩下的 2 处全在 `deploy/config/config.go`，读的是另一个文件，本就不在收敛范围内。

### 12.6 第 3 步（可选，后续）：拆文件

`config.yaml` → `config.yaml`（入库骨架）+ `env.{local,vps,n100}.yaml` + `secrets.example.yaml` / `secrets.yaml`（gitignore）；加载顺序 base → env → secrets → `MOE_*`；`MOE_ENV` 缺省 `local`。这一步与 §11 批次 2 是同一件事，**必须在凭据轮换之前落地**，否则新密钥会再次写进被跟踪的文件。

> **排期（2026-09-08）**：需求方明确「config 的拆分可以晚一点进行调整」，本步**暂缓**。但上面那句约束不变——它必须排在凭据轮换之前，否则新密钥会重复入库。

> ⛔ **取消（2026-09-16，需求方原话）**：「这个暂时不做 ，因为我这个还在开发 需要来回切换的 ，这个暂时不调整 不要总是高环境什么的 我是多机器开发 不方便」
>
> 这是**取消**，不是又一次延期。上面 09-08 那条「暂缓」已被本条取代。理由与代码质量无关，是使用方式决定的：需求方在多机器上开发，需要在环境之间来回切换，`env.{local,vps,n100}.yaml` + `MOE_ENV` 这套分层会把「切换」从一个改文件动作变成一个改环境变量再重启的动作，对他而言更麻烦。**不要再把环境分层当待办重新提出。**
>
> 连带影响：§11 批次 2 / 任务 #17「`config.yaml` 去跟踪」的前提就是先有 `secrets.yaml` 可拆出去，前提没了，该项一并**挂起**（不是完成，也不是取消——它取决于将来是否还轮换凭据）。
>
> 凭据问题并没有因此消失，只是换了处置方式：需求方已确认当前这些第三方密钥与数据库口令都是**开发期临时值，正式版会整体更换**，后端连的也是**测试库**。所以「密钥在被跟踪的文件里」这件事在开发期是可接受的已知状态，不需要靠拆文件来解决。
>
> 真正被 P0 处置的是另一类兜底：**代码里写死的口令默认值**。`admin_seed.go` 的 `admin123` 回退与 `build.gradle.kts` 的 `?: "moe123456"` 属于这一类——它们不依赖拆文件，任何时候都该删。前者已随 §25 删除，后者仍是任务 #16。

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
| `pkg/conf/load.go:201` | 1 | **新加载器自己**，不是遗留读取点——原文正是把它误算进去了 |
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

✅ **类型化侧已完全就绪**：这 50 处共涉及 **32 个唯一键，`pkg/conf` 已全部建模**，含嵌套的 `Admin.Bootstrap.Username/Password`（`config.go:71-73`）。`Config` 顶层 15 个段（`Runtime`/`Auth`/`Admin`/`API`/`Database`/`Image`/`AppClient`/`LLMInference`/`Ollama`/`LocalModels`/`TempMail`/`PrivateMessage`/`Feishu`/`Wechat`/`Moe`）覆盖了当前全部读取需求。**序 6 不缺任何结构体，纯属机械改写。**

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

> ✅ **已于批次 15 落地（见 §28），但落地方式与本段建议有三处偏差、本段另有一处漏登，均以 §28 为准**：
> ① 键名实际是 `moe.life_tick_seconds` / `life_flush_seconds` / `world_tick_seconds`（对齐同段 `bot_scheduler_tick_seconds` 的既有命名，去掉冗余的 `_interval_` 与 `game_`）；
> ② **`world_runner.go:13` 与 `types.go:41,44` 的默认值故意没有改为引用配置层** —— 照本段建议做会造出第三、第四份副本，与本条要消灭的问题同类（理由见 §28.2 / §28.3）；
> ③ 本段的表格把 `types.go:41` 标为「✗ 被覆盖」是对的，但没写出它是 **5 秒**（单元测试用缺省）而非 5 分钟；`LifeIntervals()` 未配置时若返回 0 让下游兜底，世界节奏会凭空快 60 倍，所以配置层必须显式给出 300 秒（见 §28.2）。
> ④ 本段漏登了 `internal/service/game/game.go` 里另一个硬编码的 `45*time.Second` —— 它与 `world_runner.go:13` 同值，使 `:20` 的 `interval <= 0` 守卫永不可达。§28.3 已清掉。

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

> ↪️ **第十二批已处置（§25.2 / §25.3），并且要更正本条对严重度的判断。**
>
> 本条把它记成「代码会**静默种下** `admin123` 超级管理员」，落点在弱口令。**这个定性低估了。** 当时写了「仅在超管表为空时」这个触发条件，却没有继续问一句：**那谁来触发它？** 追下去才发现 `SeedAdminAccount` 的唯一调用方是 `POST /api/admin/bootstrap/account`——一个和 `/api/admin/login` 并列写在 `internal/server/auth.go` 免鉴权白名单里的端点，请求体 `AdminBootstrapAccountReq` 还是个**空消息**，结构上就没有能携带校验凭据的字段。
>
> 所以真实性质不是「配置疏忽会导致弱口令」，是**未授权提权**：任何人在空库部署上 POST 一次，就能造出 `super_admin` 再登录拿全权 token。完整六环证据链见 §25.2。
>
> 这是**第 1 类陷阱（读了函数，却没追调用方拿它做什么）的又一次实例**，而且比通常那种更隐蔽：本条的分析在「函数内部」这个尺度上完全正确——触发条件、日志行为、轮换修不掉它，逐条都对。错的是尺度停早了。一个只在「表为空时」被调用的种账号函数，「谁能在表为空时调用它」就是它的全部安全性，而这恰恰是没问的那个问题。
>
> 连带后果：**只删这个兜底是安全表演**。被跟踪的 `config/config.yaml:28` 显式写着 `password: "admin123"`，代码不兜底，那个免鉴权端点照样能造出弱口令超管。所以处置不是「删兜底」，是「删端点 + 把种账号搬到运维本地执行的迁移里」（§25.3）。兜底也确实删了，但它是这条链上最不要紧的一环。
>
> 本条「与 §12.6 的拆分互相独立，可以先做」这个判断是**对的**，并且已经被执行；§12.6 的拆分随后被需求方取消，也没有影响到它。

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

`viper.Unmarshal` 未设 `ErrorUnused`（实测 `pkg/conf/load.go:207` 只有裸 `Unmarshal`），所以删字段不会因 YAML 里残留键而报错——这也意味着**删字段是安全的，但反过来「字段存在」不能证明「键存在」**。

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

`derive.go:153 HTTPPort()` 的**唯一调用方**就是零调用方的 `KratosAdminBaseURL()`。删掉后者，前者就变成零调用方——按「反向依赖为 0 就删」的机械判据，它也该删。

**但它不该删。** 区别在于：

| | `Kratos*` 那 4 个方法 | `HTTPPort()` |
|---|---|---|
| 迁移目标 | 已在第三批**被删除** | §12.5 序 2 **尚未开始** |
| 未来是否会有调用方 | 永远不会 | 会（`runtime.*` 迁移时） |
| 处置 | 删 | 保留 |

**判据**：`pkg/conf` 现在是一个**只建了一半的 SSOT**，它的导出函数里有两类零调用方——「目标已消失」的和「目标还没来」的。二者在 `grep` 上完全无法区分，只能靠**去查它对应的那条迁移路线是否还存在**来区分。§12.5 的表就是这份判据的来源。

同理保留的还有 `MoeProduction`（`derive.go:157` 在 `HTTPPort()` 里读 `ExternalHTTPPort`，而 `startupconfig.go:67` 已不再自己读那个 YAML 键、改为直接调 `conf.HTTPPort()`）与 `Inference()` / `GameInference()` 等。↪️ 第十一批（§24.6 #35）把这个结构体从 5 个字段削到 **1** 个 —— 剩下的 `ExternalHTTPPort` 正是上面那条链的唯一读者，另外 4 个（gRPC/pilot 三个端口 + `unified_entry`）全仓零读者已删。

### 17.6 新发现（本批未修，已记账）

| # | 发现 | 证据 | 影响 |
|---|---|---|---|
| a | **`make check` 既不跑 `gofmt` 也不跑 `go vet`** | `Makefile` 的 `check:` 只有 `go build -o /dev/null ./cmd/moe-social` + `go test ./internal/platform/moesocial/... ./internal/server/routestats/...` | 实测 `gofmt -l backend/` 命中 **127 / 928** 个跟踪 `.go` 文件（0 个是 `.pb.go` 生成物），最集中的是 `backend/model` 22 个与 `internal/service/admin` 18 个。⚠️ **本行原记的「92」是错的，第九批中途改记的「94」也是错的** —— 两次都是命令口径问题，正确口径与那个「在 `backend/` 里跑 `git ls-files 'backend/*.go'` 会静默返回空」的假清白陷阱一并写在附录 A 里。<br>**这是既有状态，与各批改动无关**：第五批的 7 个文件、第九批的 31 个文件里，只有 `pkg/moe/brain/refine.go` 在列，而它的 gofmt 差异（结构体 tag 对齐）在 HEAD 版逐字节相同。但它意味着文档里历次「`make check` 通过」的**证据强度被高估了**：它验证的范围比名字暗示的小得多<br>↪️ **第十二批已处置一半（§25.4）**：本行证据栏逐字引用的那个 `check:` 目标**已被改写**，现在是 `go build -o /dev/null ./cmd/moe-social` + `$(MAKE) test`（全仓、写死 `CGO_ENABLED=1`）。所以「验证范围比名字暗示的小得多」这半条**已关闭**——`make check` 现在真的覆盖全仓。<br>**但本行的主标题依旧成立**：`gofmt` 与 `go vet` 仍然不在 `check` 里，127/928 未格式化文件一个没动。刻意不并入：那会让 `make check` 因为一批与本批无关的历史文件而常红，等于把新门禁一上来就废掉。正确顺序是先单独跑一次 `gofmt -w` 清完存量，再把检查加进 `check` |
| b | **`pkg/moe/toolaudit` 失败根因确定：测试阈值过期于产品决定** | `record_test.go:11` 硬编码 `len(items) < 6` 即 fatal；`pkg/moe/tools/registry.go` 实测只有 **5** 个 `Name:`；最后一次改动是 `14edac0e`「移除了一些不需要的能力」 | 不是回归，是**测试没跟上主动删能力的决定**。该包只依赖 `backend/pkg/moe/core`，与本批及第四批均无关（§16.7 已用两种方式证明过既有性）。处置需产品侧确认阈值该是几<br>↪️ **第十二批已修（§25.5(c)），且没有去「确认阈值该是几」**：把数量断言换成 `len(BuildSchemaItems()) == len(tools.OpenAISchemaList())` 之后，「阈值」这个概念本身就不必存在了——用例断言的是「展示层必须与注册表逐项对齐」，注册表增删时它自动跟随，不需要任何人再去决定一个数字。顺带把旧用例里两处**看起来在断言、实际什么都没断言**的地方（空 if 体、`_ = AllowsTool(...)`）换成真断言。**本行原记的「需产品侧确认」到此作废。** 另：本文档中历次「唯一失败是 `toolaudit`」的记录（§17.6 表尾、§18、§19、§20、§22 等处）都是**当时的真实状态**，按惯例保留不改，读到那些行请连同本条一起看 |
| c | ~~**`apiconfig.Config.Image` 用 `json`/`yaml` 驼峰 tag，是序 3 的迁移陷阱**~~ ✅ **已关闭（序2.5，见 §21）** | `internal/platform/apiconfig/*.go:55-72`：`LocalDir string \`json:"LocalDir" yaml:"LocalDir"\`` 等；41 个 `json` tag / **0** 个 `mapstructure` tag（这个事实没变） | viper 的 `Unmarshal` **只认 `mapstructure`**，所以当初的担心是：序2/序3 若图省事把 `apiconfig.Config` 直接喂给 viper，所有字段会**静默落空**——正是 §12.1 的「静默取零值」。<br>✅ **序2.5 之后它不再是隐患**：`apiconfig` 结构已经不当任何 mapstructure 解码的目标（非生成代码里 `UnmarshalKey` 的**实际调用点为 0**），改为逐字段显式赋值。**故意不补 `mapstructure` tag**——补了也没人用，等于再养一个死别名（§21.5） |
| d | 仓库里有一个**二进制产物** `backend/bin/moe-social` | `grep -rn moeconf` 时命中 `Binary file backend/bin/moe-social matches` | 仓库卫生问题（§11 批次 6 范围）。二进制里还留着已删包的字符串，会让基于 grep 的审计出现幽灵命中 |
| e | **第三梯队冗余：已记账，本批刻意不动** | `moesocial/run.go:19-21` 是单行透传（`Run` → `runHTTPOnly`），`pure` / `http_only` 等限定词在单进程化后不再区分任何东西；`firstNonEmpty` 有 **6 份语义等价实现**（其中 3 份逐字节相同）+ 2 个变体；两个 `main` 重复 3 个 flag 声明 | 均为**低价值或有反效果**：为 6 行私有纯函数新建 `pkg/strutil` 属于过度抽象，代价是新增一层跨层依赖；启动链改名会碰两个入口。判断是「记账不动手」，不是「没看见」。<br>↪️ 第九批顺带消掉其中 1 份：`moeconfig/inference.go` 的 `firstNonEmpty` 随整包删除；`pkg/conf/derive.go` 那份现在是主实现 |

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

### 18.3 到 100% 的路径（2026-09-11 第九批完成后重算 —— 已走完）

**50% = 53 / 105** 这个里程碑在序2 就跨过了（60.0%），序2.5 到 61.9%，第九批一次做完序3 + 序4 + 序5，实测 **105 / 105 = 100%**。各块键数按实测唯一键计、已扣除死键：

| 块 | 覆盖的段 | 真实唯一键 | 累计 | **有效收敛率** | 状态 |
|----|---------|-----------|------|--------------|------|
| **已完成（序1 + 序6 + 序2 + 序2.5）** | 序1 `database.*` 8 + 序6 实收 33（`feishu` 12 · `wechat` 10 · `private_message` 5 · `temp_mail` 4 · `admin` 2）+ 序2 实收 22（`image.*` 12 · `runtime.*` 3 · `auth.*` 2 · `admin.*` 2 · `app_client.*` 1 · `api.*` 1 · **`moe.production.external_http_port` 1**）+ 序2.5 实收 2（`local_models.*`） | **65** | 65 | 61.9% | ✅ |
| **序 3（第九批）** | `llm_inference.*` **10** | +10 | 75 | 71.4% | ✅ 见 §22 |
| **序 4 / 序 5（第九批）** | `moe.*` **30**（19 个 `*_api_in_process` + 3 个全局闸 + 8 个调度器/模型） | +30 | **105** | **100%** | ✅ 见 §22 |

> ✅ **§12.4 那个「序3 需要签字」的前置条件已用证据结掉**（见 §22.4），不是绕过：三个 `MOE_LLM_*` 变量的唯一设置处默认值全是空串，触发条件本身就是「运维要把 LLM 端点搬走」，此时不收敛才是 §12.1 那类缺陷。
> ✅ **100% 的含义要读准**：分母 105 是「配置键的真读者」，现在**真读者归零**；口径 F 仍剩 8 处字面量，但它们是 3 处 `conf.IsSet(...)` 实参 + 5 处 `v.Set(...)` 写回，按 §18.2 的判定规则不算读者（见 §22.3）。所以「100%」= 没有任何配置键在 `pkg/conf` 之外被读取，**不等于**仓库里再没有配置键字面量。

> **记账更正（第四版）：序3 从 12 键缩到 10 键，`local_models.*` 那 2 键已由序2.5 提前收掉。**
> 总数仍是 105（41 + 22 + 2 + 10 + 30 = 105 ✅），序3 之后的累计仍是 75 = 71.4%，只是这 2 键的归属从「序3」挪到「已完成」。详见 §21。

> **记账更正（第三版）：序2 实收 22 键，不是预测的 21。**
> 差的 1 键是 **`moe.production.external_http_port`** —— 它按段名属于 `moe.*`，上一版整块划给序4/序5；但它唯一的非 `pkg/conf` 读者是 `moesocial/startupconfig.go:73` 的 `v.GetString(...)`，被序2 的增量 2f 一并换成 `conf.HTTPPort()` 后就归零了，按 §18.2 的判定规则只能记在序2 名下。所以序4/序5 的 `moe.*` 从 31 缩到 **30**，总数仍是 105（41 + 22 + 12 + 30 = 105 ✅）。
> `runtime.*` 记 3 不是 4：config.yaml 里有 4 个 `runtime` 叶子键，但 `runtime.http_host` 从来没有出现在 `pkg/conf` 之外的字面量里（`moesocial/run.go:38-52` 的 `apiListenAddr` 读的是 **API 片段**的 `Host`，不是这个键），因此它不在 §19.3 那份 64 键的普查里，两头都不计。

> **上一版最重要的结论已被证实：过 50% 确实只需要序 2 一步，且不需要签字。** 序6 → 39.0%，序2 → **60.0%**。上一版的「累计 62」也算对了，只是拆分从「序2 21」变成「序2 22」。

> ✅ **§18.3 上一版登记的三个障碍，处置结果：**
> 1. ~~`admin_runtime_config.go` 是「读—改—写」路径，`pkg/conf` 没有 setter~~ → **读路径已迁**（`ReadRuntimeConfig` 改用 `conf.Reload()`），**写路径按预判保留 viper**（`v.Set()` ×5 + `v.WriteConfig()`）。这 5 个 `v.Set` 字面量是口径 F 里仅剩的**写路径**命中，不是读者，见 §20.2。<br>↪️ **「保留 viper」这个处置已被第十一批推翻**（§24.4）：`viper.WriteConfig()` 会重新序列化整个文件，实测把真实 `config.yaml` 的 79 行注释抹成 0 行、265 行压成 154 行。写路径现在完全不经过 viper，改用 `yaml.v3` 取行列号后在原始字节上定点改行。那 5 个键字面量仍在（口径 F 计数不变），但形态从 `v.Set(k, v)` 变成 `yamlEdit{k, v}`。当时判断「没有 setter 所以必须自己开一个 viper」是对的，**漏判的是那个 viper 的写回是破坏性的** —— 只看了它能不能写，没看它写的时候顺手毁了什么。
> 2. ~~`conf.Reload()` 零调用方 → 管理台写回后缓存陈旧~~ → **已修**，`Reload()` 现有 1 个调用方（`admin_runtime_config.go:307`，第十一批前是 `:76`），且写回后追加了 `conf.LoadFile(path)`（`:352`，原 `:119`）让缓存指向刚写的文件。这是序2 唯一的真风险点，已用往返探针验证，见 §20.4。<br>↪️ **第十一批又修了 `Reload()` 自身的一个竞态**（§24.2）：它原先在重读之前把 `current` 置 nil，开出一个横跨整次读盘的窗口，窗口内并发 `Get()` 会落到包级 `searchDirs` 而不是 `-f` 指定的文件。「有调用方」和「调用方本身正确」是两件事，序2 只证成了前者。
> 3. ~~`image.oss.access_key_id/secret` 会新增环境变量兜底~~ → **未发生**。实测真实消费方 `biz/media/store_oss.go:29-34` 已经做了「文件优先、`MOE_OSS_*` 兜底」，本层再兜一遍是重复的，所以改为只取文件值（`config_override.go`），行为零变化。这条障碍是我上一版**评估过头**了。

> ✅ 上一版另一条预判成立：`config_override.go` 的 `MOE_AUTH_ACCESS_SECRET` → `auth.access_secret` 层叠与 `conf.AuthAccessSecret()` 逐字同义，直接替换即可。
> ✅ ~~序3 会撞上 §17.6(c) 那个 tag 陷阱，而它已经是一个活 bug~~ → **序2.5 已处置**（#27，见 §21）。两点更正：一是它**不是**活 bug —— 丢值真实存在，但整条离线模型链路零消费者（§19.4 已重写）；二是修完之后 `apiconfig` 结构**再也不是任何 mapstructure 解码的目标**，所以序3 不会撞上这个陷阱，§17.6(c) 整类隐患关闭。

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
| `utils/admin_seed.go` | 2 | `conf.Get().Admin.Bootstrap`；`admin123` 兜底**故意保留**（那是未授权的 #18）<br>↪️ **第十二批已删除并重写该文件（§25.3）**：兜底没了，缺口令即返回 `ErrAdminBootstrapPasswordUnset` 且不写库；`Count` 加了 `Unscoped()`；函数改为返回 `error`，调用方从免鉴权端点换成 `RunAutoMigrate` 末尾。读 `conf.Get().Admin.Bootstrap` 这一点不变 |
| `utils/auth_jwt_config.go` | 2 | **死代码删除**，非迁移，见下 |
| `utils/admin_jwt.go` | 2 | **死代码删除**，非迁移，见下 |
| `internal/biz/user/oauth_feishu.go` | 2 | `conf.Get().Feishu.Enabled` ×2 |
| `utils/feishu_oauth_redirect.go` | 1 | `conf.Get().Feishu.AppReturnURL`<br>↪️ **第十七批随 #50 整体删除（§30.2）**：回跳地址改由 `oauth.allowed_return_urls` 白名单裁定，`AppReturnURL` 配置键不复存在。当时的迁移是真的，只是产物后来没了 |
| `utils/wechat_oauth_redirect.go` | 1 | `conf.Get().Wechat.AppReturnURL`<br>↪️ 同上，**已随 #50 删除** |
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
> 连带删掉 `envAuthAccessSecret = "MOE_AUTH_ACCESS_SECRET"` 常量 —— 它是 `derive.go:21` `envAuthSecret` 的重复定义。

> ⚠️ **`wechat` 那条链是「替换 + 消掉 10 个死键」，不是逐键平移。**
> `utils/wechat_oauth_flow.go` 的 `wechatFlowCredentials()` 对每个凭证尝试 3 种历史拼写（16 个键引用），其中 **10 个键在 config.yaml 里根本不存在**。`derive.go:204` 的 `WechatFlowCredential()` 已把这条链收敛成一次调用，所以整个函数与 `firstNonEmptyConfig()` 一并删除，文件只剩 `NormalizeWechatOAuthFlow`。
> `:36` 那句注释（「勿回退公众号(mp)：移动应用 code 只能用 wechat.app 凭证换取，混用会报 10005」）是**业务约束**，已确认原样保留在 `derive.go` 里，没有随 `switch` 被简化掉。
> **代价**：`NormalizeWechatOAuthFlow` 的归一化现在与 `derive.go:206` 的 `switch` 重复。这是结构上无法消除的 —— `utils` → `pkg/conf` → `utils` 会成环。

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

### 19.4 `local_models.catalog` 的 `parameters_b` 静默丢值 —— **原判定「活 bug」是错的，已于 §21 更正并修复**

§17.6(c) 把「`apiconfig.Config` 用 `json`/`yaml` 驼峰 tag，而 viper 要 `mapstructure`」登记为**迁移陷阱**。本节最初进一步断言它「今天就在丢数据、App 把 Qwen2.5 0.5B 显示成 0B」。**丢值是真的，「活 bug」是假的** —— 后半句没做消费者追踪就下了结论。

`internal/platform/apiconfig/config.go:23-32` 的 `LocalModelCatalogEntry` 实测有 **41 个 `json:` tag、0 个 `mapstructure:` tag**。原 `config_override.go:53` 用 `v.UnmarshalKey("local_models.catalog", &entries)` 灌它，走 mapstructure 的**默认按字段名大小写不敏感匹配**，于是带下划线的蛇形键匹配不上驼峰字段。用**非零合成值**跑对照实验（真配置里 `size_bytes: 0`，零值区分不出「被丢」还是「本来就是零」）：

| 字段 | config.yaml | `apiconfig` 路径（改前） | `pkg/conf` 路径 |
|------|------------|----------------------|---------------|
| `size_bytes` | 4242 | **0** ❌ | 4242 ✅ |
| `parameters_b` | 0.5 | **0** ❌ | 0.5 ✅ |
| `id`/`filename`/`sha256`/`description`/`recommended` | — | 全部正确 ✅ | 全部正确 ✅ |

规律很清楚：**只有含下划线的键被丢**（`size_bytes`→`SizeBytes`、`parameters_b`→`ParametersB`），单词键靠大小写不敏感匹配侥幸命中。

**但被丢的值流不到任何地方。整条离线模型链路逐个环节实测都是断的：**

| 环节 | 实测 | 结论 |
|------|------|------|
| HTTP 端点实现 | `internal/server/protohttp/llm/llm.go:8-11` 的 `Server` 只嵌了 `llmv1.UnimplementedLlmChatServer`，全仓 `internal/` + `cmd/` 对 `ListLlmLocalModelsCatalog` **零实现** | `/api/llm/local-models/catalog` 返回 `codes.Unimplemented` |
| 端点注册 | `internal/server/http_proto.go:183` 确实注册了路由 | 路由通、handler 空 |
| catalog 解析函数 | `apicomm.LoadLocalModelCatalog` / `FindLocalModelByID` / `ResolveLocalModelsStorageDir` / `LocalModelMeta` 全仓**零外部调用方**（只有 `local_models.go` 内部自引用） | `ParametersB` 的透传代码是死代码 |
| 诊断快照 | `platform_llm.go:134` 写 `ConfigSnapshot.LocalModelsStorageDir/CatalogSize`，`biz/llm/platform_common.go:20-21` 声明，**零读者** | 只写不读 |
| App 侧 | `grep -rn 'local-models\|local_models\|localModels' lib/` → **0 命中** | App 从来不调这个端点 |
| 真实启动复核 | 起真二进制 `curl /api/llm/local-models/catalog` → **401 `缺少认证信息`**（连 Unimplemented 都到不了，先被鉴权中间件拦下） | 与上面一致 |

所以正确的定性是：**一个真实的静默丢值 + 一个未接线的功能**，用户可见影响为零。按 §18.1 的口径它属于「修饰性修复 = 0 分」，真正有分的是把这 2 个键的读取路径收敛掉（§21 做到了，60.0% → 61.9%）。

> ⚠️ **方法论教训（本仓第四次同类错误，方向相反）**：前面几次的错误是「grep 命中当成消费者」，这次是**反过来**——我看到 `ParametersB` 从 `resolveCatalogEntry` 透传进 `LocalModelMeta`、又对上了 proto 里的 `LlmLocalModelCatalogItem.parameters_b`，就据此断言「App 显示 0B」，**没有去查那个 proto 消息有没有 handler、那个函数有没有调用方**。链路画得再完整，只要有一环零调用方，末端就什么都不显示。断言「活 bug」的最低门槛是**从用户可见的出口反向走通到源头**，正向把代码读通不算数。

**已确认丢值是既有缺陷、非本轮引入**：`git show HEAD:` 比对，`config_override.go` 的 catalog 块与 `apiconfig` 的 tag 缺失在当时 HEAD 上**逐字相同**。

**修法与 §12.4 签字无关**（签字是关于 `MOE_LLM_*` 要开始影响 Bot 调度），已于 §21 序2.5 采用「改走 `conf.Get().LocalModels`」那条路修掉，顺带把 `apiconfig` 从 mapstructure 解码目标里彻底摘出去。

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
| 2f | `internal/platform/moesocial/startupconfig.go` | `runtime` · `moe.production` | 删掉私有 `viperForUnified()`，改 `loadUnified()` → `conf.LoadFile(-f)`；`httpPortFromUnified()` 收敛到既有的 `conf.HTTPPort()`（`derive.go:153` 的注释本就写着「与 moesocial.httpPortFromUnified 一致」，此前零调用方） |

> 🔧 **2d 修掉了 §18.3 障碍 2**：`conf.Reload()` 此前零调用方，而 `conf.Get()` 首次加载后永久缓存。管理台写回 config.yaml 后若不失效缓存，「改了图片配置不生效」会从局部小问题升级成全局问题。现在 `Reload()` 有 1 个调用方（`:307`，第十一批重写读视图后从 `:76` 移到这里），写回后再 `conf.LoadFile(path)`（`:352`）让缓存指向刚写的文件 —— `load.go:114` 那条注释要求的东西，到此才真正存在。<br>⚠️ **第十一批补记**：本条只证明了「`Reload()` 有人调」，没证明「`Reload()` 自己是对的」。旧实现先把 `current` 置 nil 再解锁重读，开出一个横跨整次读盘的窗口，并发 `Get()` 在 0.25 秒内观测到 **459501** 次错值读取 —— 见 §24.2（#31）。这正是「有调用方」与「调用方本身正确」是两件事的实例。
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

### 20.5 顺带实测到的既有缺陷：10 个文件自带 `searchDirs`，永远看不见 `-f` ✅ 已关闭（第九批，见 §22.6）

> ✅ **本批未修 → 第九批已修完**：自带硬编码 `searchDirs` 的文件实测 **10 → 0**（`grep -rln 'AddConfigPath("\.\.\./\.\./config")' backend/ --include='*.go'` 排除 `pkg/conf/` 与 `_test.go` 后为空）。`-f` 现在是**真正的全进程权威**，且这一点不是靠单测推定的：§22.6 第 2 步用一份只在 `*_tick_seconds` 上与真配置不同的探针文件，在 `backend/` 目录里（`./config/config.yaml` 真实存在且写着 60/300）启动，日志打出探针的 `tick=7s` / `tick=11s`。下面这段保留为**缺陷现场记录**。

2f 的启动实验意外给出裂脑的**现场证据**：我在临时 `-f` 文件里把 `moe.bot_scheduler_enabled` / `moe.dream_scheduler_enabled` / `moe.life_engine_enabled` 都写成 `false`，日志却照样打出 `moe bot scheduler started tick=1m0s` 与 `moe dream scheduler started tick=5m0s`。

根因不是 flag 失效，而是**读它的地方根本不读 `-f` 那个文件**：`pkg/moe/runtime/config_load.go:64-70` 与 `pkg/moe/brain/dream_schedule.go:96` 各自 `viper.New()` + 硬编码三个 `AddConfigPath`，于是加载的是 `backend/config/config.yaml`（真配置里这两个开关是 `true`）。

实测带硬编码 `searchDirs` 的文件共 **10 个**（`config_override.go` 剩余部分、`moewiring/config.go`、`apicomm/inference_props.go`、`moeconfig/inference.go`、`pkg/moe/runtime/config_load.go`、`pkg/moe/runtime/post_model.go`、`pkg/moe/brain/` 下 4 个），正是序3 + 序4/序5 的迁移面。~~**在它们迁完之前，`-f` 仍然只对 `pkg/conf` 读者权威** —— 这一条必须写在明处，否则「`-f` 已权威」会被误读成全局成立。~~ → 第九批迁完，这句警告作废；`moeconfig/inference.go` 已随 `internal/adapter/` 整个目录删除。

> ⚠️ **一处需要更正的说法，以及一个顺带查出的死键。** 我原先想写「序3/序4/序5 同样不需要新字段，`Moe` 结构体 31 个 `moe.*` 叶子键已齐」——**实测不成立**，逐键核对后的真实情况是：
>
> | | 数量 | 明细 |
> |---|---|---|
> | config.yaml 的 `moe.*` 叶子键 | **31** | — |
> | `pkg/conf` 已覆盖 | **28** | 12 个静态 `mapstructure` tag（`config.go:212-230` + `MoeProduction` ~~5~~ **1** 个，其中只有 12 个在 config.yaml 里真被设置）+ 16 个动态 `moe.<domain>_api_in_process`（`derive.go` ~~`:199-217`~~ **`:230-234`** 的 19 域表拼出，config.yaml 里实际写了 16 个）<br>⚠️ **本行是第八批（§21）当时的快照，不是现状**：那个「12 个静态 tag」数的是当时 `Moe` 结构体的字段数，而第九批（§22）往同一个结构体里又加了约 10 个字段（两个调度器开关与 tick、`bot_smart_*` 一对、两个模型键等）。`MoeProduction` 的 5 → 1 则是第十一批（§24.6 #35）删掉 gRPC/pilot 三个端口字段与 `unified_entry` 的结果。要看**当前**的建模覆盖面，用 §24.6 那份穷尽式反射核对（97 个建模字段 × 122 个文件叶子键），不要引用本行 |
> | **未建模** | **3** | `moe.default_capability_tier` · `moe.bot_post_daily_limit_default` · **`moe.enabled`** |
>
> 前两个**不是遗漏**：`pkg/conf/config.go:17-25` 那段注释已把它们连同 `server.*`、`memory.search/embedding.*`、`temp_mail.api_key` 一起登记为「全仓无 Go 读者、故意不建模」的死键。
> 第三个 **`moe.enabled` 是本批新查出的死键**：`git grep` 全仓（Go 与非 Go）**零引用**，config.yaml 里 `enabled: true` 静静躺着，且它**不在** `config.go` 那份死键清单里 —— 那份清单自称「逐个 grep 确认过，不是漏掉」，这一条就是漏掉的。已补进注释。
>
> ✅ **所以「序4/序5 不需要新增结构体字段」这个结论仍然成立，但理由要换**：不是因为 31 个键都建模了，而是因为 28 个**活键**已全部建模，剩下 3 个是死键（处置方式应是删配置或继续留注释，不是加字段）。这也与 §18.3「已扣除死键」的分母口径一致 —— 105 里本来就不含它们。

---

## 21. 2026-09-11 第八批：序2.5（#27）—— `local_models.*` 收敛，顺带摘掉 `apiconfig` 的 mapstructure 陷阱

有效收敛率 **60.0% → 61.9%**。改动面极小：**1 个文件 + 1 个新测试文件**，`config_override.go` +68 / −37。

### 21.1 改了什么

| # | 改动 | 理由 |
|---|------|------|
| 1 | `config_override.go:49-57` 的 `local_models` 块从 `v.GetString` / `v.IsSet` / `v.UnmarshalKey` 改成 `conf.Get().LocalModels` + 一个逐字段转换函数 `localModelCatalog()` | `pkg/conf.LocalModelCatalogEntry` 的 `mapstructure` tag 是正确的，且有 `conf_test.go:186-190` 常驻断言 `ParametersB == 0.5`。§19.4 那个丢值从根上消失 |
| 2 | 顶部的 `if err := v.ReadInConfig(); err != nil { return }` 改成 `if v := readInferenceFragment(); v != nil { …只包 llm_inference… }` | 见 §21.3，这是本批**唯一有实质风险的既有缺陷** |
| 3 | 新增 `config_override_test.go`（2 条常驻测试） | 见 §21.4 |

「仅当值非空/为正才覆盖」的语义按 §20 的口径原样保留：`storage_dir` 加了 `TrimSpace`（与紧邻的序2 各段一致；消费方 `ResolveLocalModelsStorageDir` 本来就 trim，零可观测差异），catalog 的有效守卫从 `IsSet(...) && len(entries) > 0` 简化为 `len(lm.Catalog) > 0`（两者在空列表、键缺失两种情况下结论相同，而旧写法还会在 unmarshal 出错时静默不覆盖）。第二条常驻测试专门守这个语义。

**副作用收益**：`config_override.go:54` 是全仓**唯一**一处拿 `apiconfig` 结构当 mapstructure 解码目标的地方（改后 `UnmarshalKey` 在非生成代码里的实际调用点 = **0**）。所以 §17.6(c) / §19.4 那类「41 个 `json` tag、0 个 `mapstructure` tag」的隐患**整类关闭** —— `apiconfig` 从此只经 `yamlconf.MustLoad` 的 `yaml.Unmarshal` 解析片段，那条路认的是 `yaml` tag，本来就有。

### 21.2 口径 F 实测

| 指标 | 序2 后 | **序2.5 后** |
|------|-------|------------|
| 出现次数 | 68 | **65** |
| 唯一键字面量 | 49 | **47** |
| 其中真有非 `pkg/conf` 读者的键 | 42 | **40** |
| 真读者命中行数 | 59 | **56** |
| 涉及文件 | 28 | **28**（`config_override.go` 仍留着 `llm_inference` 读 + `image.*` 写回） |
| `pkg/conf` 反向依赖 | 23 | **23**（该文件早就 import 了 `conf`） |
| 遗留 `viper.New()` | 16 | **16**（挪进了 `readInferenceFragment()`，没减） |
| 自带 `searchDirs` 的文件 | 10 | **10**（同上） |
| `apiconfig` 作为 mapstructure 解码目标 | 1 | **0** |
| **有效收敛率** | 63/105 = 60.0% | **65/105 = 61.9%** |

剩下 40 个真读者 = `llm_inference.*` **10**（序3）+ `moe.*` **30**（序4/序5）。`local_models.*` 段**归零**，用差集验过：序2 后与序2.5 后的真读者唯一键差集正好是 `local_models.catalog` 与 `local_models.storage_dir` 两条，不多不少。

### 21.3 顺带修掉的真缺陷：viper 读不到文件时，**所有** `pkg/conf` 覆盖被一起跳过

改前 `ApplyUnifiedConfigOverrides` 的第 6 行就是 `if err := v.ReadInConfig(); err != nil { return }`，而序2 加进来的 `Image` / `Auth.AccessSecret` / `AdminJWT` / `ClientPublicApiBaseUrl` 各段全在这个 `return` **后面**。也就是说：只要 viper 那三个硬编码 `searchDirs`（`./config`、`../config`、`../../config`）在当前 cwd 下解析不到，这些**与 viper 毫无关系**的 `pkg/conf` 覆盖也会被一并静默跳过。

这不是理论风险，它与 §20.3 直接冲突：序2 让 `-f` 对 `pkg/conf` 权威之后，`-f /别处/alt.yaml` 从一个没有 `config/` 的目录启动时，`pkg/conf` 能正常加载，但这个函数会在第一行就 bail —— **`-f` 权威了，覆盖层却整层失效**。

本包 cwd（`internal/platform/wiring/`）下三个 `searchDirs` 恰好都不存在（`wiring/config`、`platform/config`、`internal/config` 实测均无），所以新测试天然落在这个分支里，HEAD 负对照把它拍成了实证：同一条测试在 HEAD 上 **FAIL**（`StorageDir = ""`，即整层没生效），改后 **PASS**。

### 21.4 验证

| 层级 | 手段 | 结果 |
|------|------|------|
| 编译/静态 | `go build ./...` · `go vet ./...` | rc=0 / rc=0 且 0 行输出 |
| 格式 | 逐文件 `gofmt -l` + **正对照** | 改动的 2 个文件干净；正对照 `gofmt -l utils/admin_runtime_config.go` 确实点名（证明命令有效，空输出不是假清白） |
| 回归 | `go test ./...` | **33 包 ok**（比序2 后多 1 个：`internal/platform/wiring` 现在有测试了），唯一失败仍是既有的 `toolaudit.TestBuildSchemaItemsCoversAllTools`（§17.6(b)） |
| 新常驻测试 | `TestOverridesKeepUnderscoreCatalogFields` · `TestOverridesLeaveFragmentValuesWhenConfSilent` | 均 PASS。前者用**合成非零值**（`size_bytes: 64`、`parameters_b: 0.5`），零值区分不出「被丢」与「本来就是零」 |
| **HEAD 负对照** | 把新测试拷进 `git worktree add … HEAD --detach` 跑 | 第 1 条 **FAIL**（`StorageDir = ""`）、第 2 条 PASS → 测试有分辨力，并顺带暴露 §21.3 |
| **真实启动** | 真二进制 `-f config/config.yaml` | 监听 `*:8888`，日志 30 行**零 error/panic/fatal**，`图片: dir=/app/data/images public=… max=1073741824` 证明 `pkg/conf` 覆盖链在改后仍然生效 |
| **启动差分** | HEAD 二进制 vs 改后二进制，同参数各起一次，把时间戳/仓库路径/SQL 耗时归一后逐行 diff | 20 行启动序列**唯一差异**：`SELECT * FROM life_items` 的 `rows:570` vs `rows:576`（见下） |
| 端点复核 | `curl /api/llm/local-models/catalog` | 两次启动均 **401 `缺少认证信息`**，与 §19.4「端点无实现、且先被鉴权中间件拦下」一致 |

> ✅ **`rows:570` vs `rows:576` 已归因，不是本批造成的**：两次启动相隔 60 秒打在**同一个共享测试库**上，先起的那次执行了 `internal/data/life/store.go:261` 的种子 `INSERT … ON DUPLICATE KEY UPDATE id=id`（6 条 `life_items`），后起的那次自然多看到 6 行。交叉证据：`git diff --name-only` 只有 `config_override.go` 一个文件，而该文件对 `gorm|sql|INSERT|SELECT|store.` 的命中数是 **0** —— 它根本碰不到数据库。

> ⚠️ **本轮踩到的三个工具陷阱，都差点产出假结论：**
> 1. **归一化正则用错日期分隔符，第一次「差分」100% 是噪音。** Go 标准库 `log` 的默认时间戳用**斜杠**分隔年月日，而我按横线写正则，那条 `sed` 从头到尾没生效，于是 20 行「差异」全是时间戳本身。差点据此写下「启动日志有差异」。靠**正对照**抓住：先单独打印 `norm | head -1`，要求它「必须看不到时间戳」，一看还在，才知道归一化没跑通；再用 `od -An -c` 数首行第 5 字节确认是 `/`、前 10 字符里横线数为 **0**（终端把斜杠日期渲染成横线，肉眼看日志是判不出来的）。**校验命令自己也需要被校验。**
> 2. **`$!` 有一次没展开，`kill` 收到字面量 `$!`，HEAD 的服务留在 8888 上。** `ps` 报 `Invalid process id: $!`。同一写法在前一次调用里是正常的（拿到 87471），所以这不是可依赖的行为。改成用 `lsof -nP -iTCP:8888 -sTCP:LISTEN` 反查 PID 再 kill，并**复查端口已空 + `pgrep` 无残留**才算收拾干净。**杀进程不能只看命令没报错，要验证目标真的没了。**
> 3. **Bash 工具的 cwd 并不总是如预期保持。** 一次 `cd /tmp && …` 之后，下一条用相对路径的 `head -1 boothead.log` 直接报 `No such file or directory`；更早还有一次 `cd backend` 之后用仓库根相对路径 `grep docs/dev/…` 同样扑空。更危险的是**扑空的表现形式和「没有命中」一模一样**。本批之后一律用绝对路径，或在每条命令里显式 `cd`。

### 21.5 未处置（本批故意没动）

- **整条离线模型链路是死的，删或接线是产品决定，不该由配置治理顺手做掉。** 实测清单见 §19.4 那张表：`apicomm/local_models.go` 的 `LoadLocalModelCatalog` / `FindLocalModelByID` / `ResolveLocalModelsStorageDir` / `LocalModelMeta` **四个导出符号零外部调用方**（`ParseHTTPByteRange` 也只有测试在用）、`ConfigSnapshot.LocalModelsStorageDir/CatalogSize` **只写不读**、`ListLlmLocalModelsCatalog` **零实现**、`api/etc/moe.yaml:29-31` 的 `LocalModels` 段恒为空、Flutter 侧零引用。用户既有的「死配置能先收掉」授权针对的是**配置键**，不覆盖删功能代码，所以这里只登记不动手。
- `readInferenceFragment()` 仍然自带那三个硬编码 `searchDirs`，是 §20.5 那 10 个文件之一 —— 序3 把 `llm_inference` 迁进 `pkg/conf` 后，这个函数与它唯一的调用方一起删（注释里已写明）。
- `apiconfig.LocalModelCatalogEntry` 本身**保留**：它仍是片段的传输形状，也是将来给离线模型接线时的落点。本批只是让它不再当 mapstructure 的解码目标，没有补 `mapstructure` tag（补了也没人用，等于再养一个死别名）。
  > ✅ **第九批已处置上一条**：`readInferenceFragment()` 连同它唯一的调用方一起删除（见 §22.2）。§20.5 那 10 个文件现已归零。

---

## 22. 2026-09-11 第九批：序3 + 序4 + 序5 —— 有效收敛率 61.9% → **100%**

一次做完 §12.5 剩下的三序。改动面 **31 个 `.go` 文件（30 改 + 1 删）**；工作区（第八批 + 第九批合计）`32 files changed, +510 / −428`，其中第八批的份额见 §21。

### 22.1 本批最重要的发现：目标 API 早就建好了，而且**零调用方**

§12.4 把序3 标成「需要签字才能动」。我按签字流程先去读 `pkg/conf` 打算写清影响面，结果发现问题根本不在签字上：

| 方法 | 建立于 | 本批之前的非测试调用方 |
|------|--------|----------------------|
| `conf.TopicAnalyzeModel()` | 序2（§20.1） | **0** |
| `conf.ContextTokens()` | 序2 | **0** |
| `conf.DomainInProcess()` / `InProcessDomains()` / `DefaultInProcessEnabled()` | 序2 | **0** |
| `conf.GameInference()` | 序2 | **0** |
| `conf.BotPostModel()`（本批改名收窄为 `BotPostModelConfigured()`） | 序2 | **0** |

序2 已经把这 40 个键的落地形状**全部实现并写了用例**，却没有接上一个生产调用点。这是 §16.2「`pkg/conf` 此前一整天是死代码」的**同型复发**，只是更隐蔽：那次整个包没人导入，编译期就能看出来；这次包被导入了、方法也在、测试全绿，只有「没人调」这一件事是错的。

> **教训（本文档第 4 次记录同一类错误，前三次见 §13.3 / §16.2 / §19.4）**：**SSOT 里存在一个 helper ≠ 有人用它。**「建好目标」与「接线」是两步，只做第一步会让进度**看起来**完成，而原读者一行没少。判定一批迁移是否真的落地，唯一可靠的指标是**原读取点的剩余行数**（口径 F 的「真读者」那一列），不是新 API 的数量，也不是测试是否通过。
> 镜像形式同样成立：§12.4 那条「零调用方的迁移目标」（`KratosAdminBaseURL`）是**目标没了、helper 还在**；本批是**helper 还在、目标也还在，只是两者没连起来**。三种形态都只能靠数调用方发现。

于是本批的实际工作不是「设计新访问器」，而是**删掉重复读者、把调用点指向已有的方法**。`pkg/conf` 新增的表面只有 6 个符号：`RawInference` 类型 + `ResolveInference()`、`LifeEngineEnabled()`、`BotScheduler()`、`DreamScheduler()`、`SmartRetry()`、私有的 `inheritBool()`；另有 1 个改名收窄（`BotPostModel()` → `BotPostModelConfigured()`）。

### 22.2 改了什么

| 文件 | 变化 | 说明 |
|------|------|------|
| `internal/adapter/moeconfig/inference.go` | **删除**（77 行） | 序3 的另一个读者。删掉后 `internal/adapter/` 整个目录消失 |
| `internal/platform/moewiring/config.go` | 82 → **48** 行 | `configOnce` / `configV` / `moeViper()` / `boolOr()` / `defaultInProcessEnabled()` / `domainInProcessEnabled()` 全部删除，只剩 4 个导出薄封装（`wiring/wire_*.go` 有 20 处调用方，不能直接删） |
| `pkg/moe/runtime/config_load.go` | 87 → **37** 行 | `LoadInferenceFromViper` 删除；`LoadSmartOpts` / `LoadSchedulerOpts` 改走 `conf.SmartRetry()` / `conf.BotScheduler()` |
| `internal/platform/moewiring/api_*.go` × 17 | 每处 1 行 | `domainInProcessEnabled("moe.X_api_in_process")` → `conf.DomainInProcess("X")`，19 个键字面量随之消失 |
| `pkg/conf/derive.go` | 282 → **349** 行 | 新增 §22.1 那 6 个符号；`Inference()` 重构为 `ResolveInference()` 的解析版 |
| `internal/platform/wiring/config_override.go` | — | `readInferenceFragment()` 删除；`llm_inference` 段改用 `conf.ResolveInference()`，`os` 与 viper 导入随之移除 |
| 其余 8 个手改文件 | — | `bootstrap/scheduler.go`、`protohttp/moe_extended.go`、`runtime/post_model.go`、`brain/{refine,dream_schedule,topic_analyze,prompt_memory}.go`、`apicomm/inference_props.go` |

被删掉的重复实现共 **5 个同名/同职能函数**：`loadBotPostModelFromViper` ×2（`runtime` 与 `brain` 各一个，**回退链还不一致**）、`loadTopicAnalyzeModelFromViper`、`defaultContextLimit`、`ContextLimitFromViper`。另外 `8192` 这个上下文长度兜底字面量此前在 `apicomm` 与 `brain` 各写一遍，现在只有 `conf.DefaultContextTokens` 一处。

### 22.3 口径 F 实测：分母已清空

```
出现次数 = 8    唯一键 = 7    涉及文件 = 3
真读者命中行数 = 0    真读者唯一键 = 0
有效收敛率 = (105 − 0) / 105 = 100%
```

剩下的 8 处**全部不是读者**，与 §20.2 的分类一致：3 处 `conf.IsSet(...)` 实参（`oauth_wechat.go:24,66`、`config_override.go:93`）+ 5 处写回键字面量。反向校验（有键字面量但该行不含任何查找调用）**为空**。

> ↪️ **第十一批（§24.4）后这 5 处的形态变了，但计数不变**：写回不再经过 viper，所以 `v.Set("image.max_bytes", …)` 变成了 `yamlEdit{"image.max_bytes", …}`，行号从 `admin_runtime_config.go:97,100,105,108,111` 移到 **`:331,334,337,340,343`**。数量（5）、文件（1）、语义角色（写回而非读取）全部不变，因此**口径 F 的 8 处 / 7 键 / 3 文件 / 0 读取行 / 100% 逐字保持**。

| 指标 | 基线 `14370f93` | 序2 后 | 序2.5 后 | 第九批后 | **第十一批后** |
|------|----------------|--------|----------|-----------|-----------|
| 口径 F 出现次数 | 254 | 68 | 65 | **8** | **8**（形态由 `v.Set` 变 `yamlEdit`） |
| 真读者唯一键 | — | 42 | 40 | **0** | **0** |
| 有效收敛率 | 0% | 60.0% | 61.9% | **100%** | **100%** |
| 自带 `searchDirs` 的文件（§20.5） | — | 10 | 10 | **0** | **0** |
| `viper.New()` 站点 | 20 | 16 | 16 | 3 | **2** |
| `pkg/conf` 反向依赖文件 | 0 | 23 | 23 | **49** | **49** |

`viper.New()` 幸存者逐个有据。第九批后是 3 处：`deploy/config/config.go:43,50` 读的是**另一个** `deploy/config.yaml`（Deploy Agent 自带 base+override 合并逻辑，正是 §12.6 拆文件时要抄的样板，不在收敛范围内）；第三处 `utils/admin_runtime_config.go:56` 是「读—改—写」的写路径，当时的理由是「`pkg/conf` 没有 setter」。**第十一批把第三处删了**：§24.4 用 `yaml.v3` 取行列号、在原始字节上定点改行取代了 `viper.Set` + `WriteConfig()`，那个「没有 setter 所以必须自己开一个 viper」的绕法随之消失。写路径的收尾仍是一次 `conf.LoadFile(path)`（现 `:352`），进程内缓存照样跟得上文件。现在只剩 `deploy/config/config.go` 那 2 处，本就不在收敛范围内 —— §12.5 尾注那句被划掉的预测至此逐字兑现。

### 22.4 §12.4 那条「需签字」的行为变更：用证据结掉，没有去问

签字项是：`Inference()` 认全部 4 个 `MOE_LLM_*`，于是 `MOE_LLM_BASE_URL` / `API_STYLE` / `MODEL` **将开始影响 Bot 调度**（此前只影响记忆抽取与 Companion）。

实测这三个变量的**唯一设置处**是 `backend/docker-compose.binary.yml:10-12`，默认值全是空串 `${VAR:-}`。也就是说：只有当运维**显式**去设一个「其唯一用途就是把 LLM 端点搬走」的变量时，这个超集行为才会触发；而在这种情况下让 Bot 调度继续连旧端点，恰恰就是 §12.1「同一件事两条链」要消灭的缺陷本身。

所以这不是需要权衡的取舍，而是**不收敛才是 bug**。已就地结掉，理由逐字写进 `derive.go` 的 `ResolveInference()` 文档注释（而不是只写在本文档里），§12.4 同步更新。

### 22.5 三处回退链变化：逐条证明当前惰性

迁移把两处同名函数合成一处，必然要选一条链，因此有三处链形变化。**每一条都在合并前实测过当前是否惰性**：

| 变化 | 影响面 | 当前是否惰性 | 证据 |
|------|--------|-------------|------|
| `brain/refine.go` 的模型链**变宽一级**（新增 `llm_inference.chat_model`） | Bot 发帖精炼用哪个模型 | ✅ 惰性 | `config.yaml` 里 `chat_model` 不存在（只有 `llm_inference.chat_model: ""` 出现在测试 fixture） |
| `Inference()` 链**变宽一级**（新增 `ollama.*`） | 全部推理调用 | ✅ 惰性 | `config.yaml` 的 `ollama:` 整段被注释掉 |
| 两个 `loadBotPostModelFromViper` **合一**（原先 runtime 认 `chat_model`、brain 不认） | 同上第一条 | ✅ 惰性，且这是修掉一处 §12.1 类缺陷 | 两个同名函数回退链不一致，本身就是「同一件事两条链」 |

**刻意没有变宽的一处**：`BotPostModelConfigured()` 只到文件层（`moe.bot_post_model` → `llm_inference.chat_model`）就停，**不接** `Inference().DefaultModel`。原因是两个调用方（`runtime.resolvePostModel`、`brain.resolveRefineModel`）紧接着就查各自的 `deps.Inference.DefaultModel`，那是**调用方注入的运行时数据**（`generate_test.go:81` 就靠这个可注入性构造 `Deps`）。在 conf 层再兜一遍会把注入值悄悄盖掉。原先序2 建的 `BotPostModel()` 恰恰多兜了这一级，本批改名并收窄，新增用例 `TestBotPostModelConfiguredStopsAtFileLayer` 的第三条断言专门守这一点。

### 22.6 验证

静态：`go build ./...` rc=0 / 0 行输出；`go vet ./...` rc=0 / 0 行输出；`go test ./...` **33 个包 ok**，唯一失败仍是 §17.6(b) 那个既有的 `toolaudit.TestBuildSchemaItemsCoversAllTools`（阈值 `>=6` vs 实际 5 个工具，待产品决定）。

`gofmt`：全仓不洁 **127 / 928** 个跟踪 `.go` 文件（0 个是生成物）。⚠️ **§17.6(a) 原记的「92」与本批中途记的「94」都是错的**，正确口径是 `gofmt -l backend/`。本批 31 个改动文件里只有 `pkg/moe/brain/refine.go` 在列，而它的 gofmt 差异（`refineLLMJSON` 结构体 tag 对齐，:53-57）在 HEAD 版**逐字节相同** → 本批新增 **0**。

新增 6 个用例（`pkg/conf/conf_test.go`），全部带**判别性断言**——即在「最自然的错误实现」下必然失败：

| 用例 | 判别性断言 |
|------|-----------|
| `TestResolveInferenceIsRaw` | 原值保留末尾斜杠 / `api_style` 为空时不猜 / 超时不填 120。第三条尤其要紧：若原值也返回 120，`config_override.go` 里 `if TimeoutSeconds > 0` 的守卫就会把文件没写的超时凭空写进片段 |
| `TestBotPostModelConfiguredStopsAtFileLayer` | 两级都空时返回 `""`，**不得**回落 `memory_model` |
| `TestTopicAnalyzeModel` | 与上一条形成对照：这条链**是**要落到 `memory_model` 的 |
| `TestSchedulersInheritTrueWhenUnset` | 键**不存在**时返回 `true`（类型化 bool 会给 `false`）；`tick_seconds` 写 0 / 负数时保留缺省 |
| `TestSmartRetry` | 缺失时返回 `(0, 0)` 而不是兜底值 |
| `TestLifeEngineEnabledInherits` | 四种组合：显式 true / 未设置+闸开 / 未设置+闸关 / 显式 false |

**负向对照（实做，不是推理）**：把 `derive.go` 临时改成 4 种「最自然的错误实现」（`BotPostModelConfigured` 多兜一级、两个调度器改用类型化 bool、`ResolveInference` 归一化 `BaseURL`），6 个用例中 3 个失败，且失败的正是预期的那 3 条断言；随后 `diff` 确认文件已按字节还原。**这一步是必须的**——按 §13.3 的教训，一个静默通过的测试和一个静默为空的 grep 一样，都是假清白。

**真实启动 + 差分启动**（按「确保每一次的调整完 程序都是正确可运行」这条标准）：

1. 当前工作区与 HEAD 各构建一个二进制，在同一工作目录、同一 `-f config/config.yaml` 下各启动 25 秒。两份日志归一化（剥时间戳、GORM 耗时、ANSI 色码）后**逐行比对**：唯一差异是 GORM 打印的编译期源文件路径（HEAD 那个二进制在 worktree 里构建）与 `life_items` 行数（见 §22.7）。22 个域的装配清单、`图片: dir=… public=… max=…`、两个调度器的 tick、`ready: Kratos HTTP-only on port 8888` 全部一致。
2. **`-f` 权威性的正向探针**：造一份只在 `bot_scheduler_tick_seconds: 7` / `dream_scheduler_tick_seconds: 11` 上与真配置不同的探针文件（合成非零值，既不同于真配置的 60/300，也不同于代码缺省的 60/300），**在 `backend/` 目录里**用 `-f /tmp/diffcfg/config.yaml` 启动 —— 该目录下 `./config/config.yaml` 真实存在且写着 60/300。结果日志打出 `tick=7s` / `tick=11s`，即 `-f` 赢了同目录的 searchDirs 命中。
3. HEAD 侧不需要再启一次：它的 `runtime/config_load.go:16-21`、`brain/dream_schedule.go:88-93`、`moewiring/config.go:17-22` 各自 `viper.New()` + `SetConfigName("config")` + 三个 `AddConfigPath`，**`-f` 的值根本没有传进去的通道**，这是静态可判定的。§20.5 记录的那次「写了 false 却照样启动」的裂脑现场，至此关闭。
4. 清理已验证：worktree 已 `remove` + `prune`（`git worktree list` 只剩主工作区），两个临时二进制与探针文件已删，`pgrep -fl` 无残留进程，`lsof -nP -iTCP:8888 -sTCP:LISTEN` 已释放。

常驻闸门复跑：`TestUnifiedFlagIsAuthoritativeForAllReaders` PASS、`go test ./internal/platform/wiring/ -run 'TestOverrides'` 两条 PASS、`pkg/conf` 全部 21 个用例 PASS、序6 的「全局单例直读必须归零」PASS（对照组 HEAD = 64）。

### 22.7 差分启动顺带查出的既有缺陷：`life_items` 每次启动插 6 行

两次启动之间，`SELECT * FROM life_items` 的行数从 **582 涨到 588**，而两份日志里的种子语句**完全相同**：

```
INSERT INTO `life_items` (…) VALUES (6 条) ON DUPLICATE KEY UPDATE `id`=`id`   [rows:6]
```

根因：`internal/data/life/store.go:259` 的 `SeedItems` 用 `clause.OnConflict{DoNothing: true}`，GORM 在 MySQL 上把它翻译成 `ON DUPLICATE KEY UPDATE id=id`，而这要求**存在唯一键冲突**才生效。但 `model/life_item.go:8` 的 `Name` 只有 `gorm:"size:64;not null"`，**没有 `uniqueIndex`**，主键 `id` 又是 `autoIncrement` 永远不撞 —— 于是 `DoNothing` 永远不会触发，**每次进程启动都往表里加 6 条重复道具**。按 588 行推算，这张表已经被启动过约 98 次。

- **与本批无关**：`internal/data/life/` 与 `model/life_item.go` 都不在改动面里，两个二进制执行的 SQL 逐字节相同。这是差分启动这个手段**顺带**照出来的既有缺陷，不是本批引入的回归。
- **本批的启动确实各贡献了 6 行**（4 次启动共 24 行）。目标库是需求方确认过的测试库，但仍应记账。
- **修法需要动共享库的表结构**（先去重、再加 `uniqueIndex`），属迁移操作，不该由配置治理顺手做掉。已登记为待决项。

> ↪️ **第十二批已处置（问题 17）**：`model/life_item.go` 的 `Name` 加 `uniqueIndex:idx_life_items_name`；`utils` 迁移框架给 `MigrateEntry` 加 `BeforeMigrate` 钩子（仅该表本次需要迁移时执行），`life_items` 条目挂 `dedupeLifeItemsByName` —— 建唯一索引前先把同名重复行归并（保留最小 ID；`life_inventory` 是唯一外键读者，挂在重复行上的背包先累加/改指到保留行再删行，全程一个事务且幂等）。共享测试库实测：**600 → 6 行**、`life_inventory` 悬空引用 **0**、唯一索引 Non_unique=0。判别性测试见 `utils/life_items_dedupe_test.go`（旧表形态用 raw SQL 模拟，覆盖累加/改指/多 dup 三种归并与 RunAutoMigrate 集成）。
- 连带影响：`life_items` 里同名道具现在有约 98 份副本，任何按名字取道具的路径都会拿到任意一条 —— 后果严重程度取决于消费方，本次未追。

### 22.8 未处置

- **`ollama.*` 回退现在可以删了。** §17.3 当时删掉 15 处恒零值回退，但 `ResolveInference()` 里还留着 5 处（`base_url` / `api_style` / `timeout_seconds` / `memory_model` / `api_key`）。本批之后 `Config.Ollama` 结构体**只剩这一个读者**，且 `config.yaml` 里该段整段被注释。删除前仍需按 §17.5 的判据确认「没有线上副本依赖它」——VPS 上的 `config.yaml` 与仓库已永久分叉（§0 第 9 行），仓库里注释掉不代表线上没有。
- §17.6 的 (a) `make check` 不跑 gofmt/vet（**127** 个文件不洁）、(b) `toolaudit` 阈值、(d) 被提交的二进制 `backend/bin/moe-social` 造成 grep 幽灵命中、(e) 三级冗余，均仍只记账未修。
- ~~#19（Life 引擎 Tick/Flush 间隔是编译期常量）、#29（离线模型死链路删或接线）仍待产品决定。~~ → **两项均已结**：#29 由第十四批决策为「整链删除」并落地（§27.3）；#19 由第十五批落地为三个配置键（§28），无需产品决定 —— 它不是「删还是补活」，是「可配还是不可配」。
- **config 拆分（§12.6 / 批次 2）已被需求方取消，不是「暂缓」**（2026-09-16 原话见 §12.6 的 ⛔ 块，§25.9 亦有摘要）：多机器开发要来回切换，环境分层会把「改文件」变成「改环境变量再重启」，对需求方更麻烦。**不要再把它当待办推进，也不要再提环境分层方案。** 连带 #17「`config.yaml` 去跟踪」一并挂起。本批让 `-f` 成为全局权威这一点对该决定无影响 —— 它的收益（配置只有一个权威来源）不依赖拆分是否发生。

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
grep -oE "$KEYRE" /tmp/F_WORK.txt | wc -l                 # 出现次数 → 8（基线 254 / 第五批后 192 / 序6后 116 / 序2后 68 / 序2.5后 65）
grep -oE "$KEYRE" /tmp/F_WORK.txt | tr -d '"' | sort -u | wc -l   # 唯一键 → 7（基线 155 / 第五批后 118 / 序6后 65 / 序2后 49 / 序2.5后 47）
cut -d: -f1 /tmp/F_WORK.txt | sort -u | wc -l             # 涉及文件 → 3（基线 48 / 第五批后 46 / 序6后 31 / 序2后 28）
grep -c 'backend/pkg/conf/' /tmp/F_WORK.txt               # 必须 0，否则 EXCL 失效（见上面的 ⚠️）
# 唯一键 ≠ 未收敛键：剩下的 7 个键**全部已无读者**（3 处 conf.IsSet 实参 + 5 处 v.Set 写回，
# 逐行清单见 §22.3）。有效收敛率的分子必须用「真读者」这一列，否则会把写路径当成漏迁。
# ✅ 原先「行数 ≠ 出现次数」那个差 1 的陷阱已消失：它来自 moewiring/api_life.go:12 一行里
#    有两个键字面量，该行现在是 conf.LifeEngineEnabled() || conf.DomainInProcess("life")，
#    一个字面量都没有了。两列都是 0，不再有可对不上的余地。
grep -vE '\.Set\(|conf\.IsSet\(' /tmp/F_WORK.txt > /tmp/F_READ.txt        # 真读者命中行数 → 0（序2后 59 / 序2.5后 56）
grep -oE "$KEYRE" /tmp/F_READ.txt | tr -d '"' | sort -u | wc -l           # 真读者唯一键 → 0（序2后 42 / 序2.5后 40）
# 有效收敛率 = (105 - 0) / 105 = 100%（序2.5 后是 (105-40)/105 = 61.9%）
# ⚠️ 归零之后这条命令**必然静默为空**，而空输出既可能是「真的收敛完了」也可能是
#    「正则写错了」。所以必须跑下面那条反向校验，并用 HEAD 做对照组。
grep -oE "$KEYRE" /tmp/F_READ.txt | tr -d '"' | sort -u | awk -F. '{print $1}' | uniq -c   # → 无输出
# 基线同口径（git grep -E 不支持 \b，只能用字符类；输出前缀 HEAD: 要剥掉）
git grep -nE "$KEYRE" HEAD -- 'backend/*.go' | sed 's/^HEAD://' | grep -vE "$EXCL" > /tmp/F_HEAD.txt
# 唯一键差集 = 本批消失的键，逐个分类成「已迁移」还是「死键删除」（§18.2 那张表）
comm -23 <(grep -oE "$KEYRE" /tmp/F_HEAD.txt | tr -d '"' | sort -u) \
         <(grep -oE "$KEYRE" /tmp/F_WORK.txt | tr -d '"' | sort -u)
# 反向校验：找出「有键字面量但该行不含任何查找调用」的行，即 §13.3 的命中≠消费
# 注：firstViperString/firstViperInt64 已随 §19.1 批6a 删除，firstNonEmptyConfig 已随 §19.2 序6 删除，
#     moeViper()/boolOr()/domainInProcessEnabled() 已随 §22 第九批删除；
#     留在正则里是为了仍能扫描 HEAD 及更早的快照。
# ⚠️ 第九批之后**必须**带上末尾那串 conf.* 访问器：剩下的 8 处字面量全部坐在
#    conf.IsSet(...) 实参或 v.Set(...) 写回上，漏掉 conf.* 会让这条校验变成假清白。
LOOKUP='(v|v2|viper|moeViper\(\))\.(GetString|GetInt|GetInt64|GetBool|GetFloat64|GetStringSlice|IsSet|GetDuration|UnmarshalKey|Set)\(|first(NonEmptyString|PositiveInt64|NonEmpty|ViperString|ViperInt64|NonEmptyConfig)\(|boolOr\(|domainInProcessEnabled\(|getBool\(|conf\.(IsSet|DomainInProcess|LifeEngineEnabled|BotScheduler|DreamScheduler|SmartRetry|TopicAnalyzeModel|BotPostModelConfigured|ContextTokens|Inference|ResolveInference|GameInference)\('
grep -vE "$LOOKUP" /tmp/F_WORK.txt                        # → 空（8 处字面量全都坐在查找/写回调用上）

# 收敛的真实指标：pkg/conf 的反向依赖（§16.2 / §19.2 / §20.2 / §22.3）
grep -rln '"backend/pkg/conf"' backend/ --include='*.go' \
  | grep -v 'backend/pkg/conf/' | grep -v '_test.go' | wc -l              # → 49（基线 0 / 第五批后 1 / 序6后 17 / 序2后 23）
grep -rn 'viper\.New()' backend/ --include='*.go' \
  | grep -v '_test.go' | grep -v 'backend/pkg/conf/' | wc -l              # → 2（基线 20 / 序6后 19 / 序2后 16 / 第九批后 3 / 第十一批后 2）
#   → deploy/config/config.go:43,50（读另一个 deploy/config.yaml，不在收敛范围）
#     ↪️ 第九批时的第 3 处 utils/admin_runtime_config.go:56 已由第十一批删除（§24.4），见 §12.5 尾注

# 序6 的决定性安全闸：全局单例直读必须归零（§19.2）
# ⚠️ 空输出要用**钉住的提交**对照验证正则本身有效，否则是假清白。
# ⚠️⚠️ 对照组**不能写 HEAD**：本行原写 `git grep ... HEAD`，当 HEAD 还是 bec11b26 时确实是 64；
#      但修复合并进 HEAD（c083ce8a）之后它自动变成 0 —— 与被测值相同，对照就此失效，
#      而它存在的唯一目的就是防「正则/pathspec 失效导致的空输出假清白」（见本附录末尾那条警告）。
#      **正向对照会随提交自动腐烂，必须钉在早于该修复的提交上。** 实测四个提交：
#      14370f93 = 64 · bec11b26 = 64 · 4f51845e = 0 · c083ce8a = 0
GS='viper\.\(GetString\|GetInt\|GetInt64\|GetBool\|IsSet\|Set\|Get\|ConfigFileUsed\|ReadInConfig\|SetConfigName\|AddConfigPath\)('
grep -rn "$GS" backend/ --include='*.go' | grep -v '_test.go' | grep -v 'backend/pkg/conf/' | wc -l   # → 0
git grep -n "$GS" 14370f93 -- 'backend/*.go' | grep -v '_test.go' | grep -v 'backend/pkg/conf/' | wc -l   # → 64（对照组，钉在基线）
grep -rn 'InitConfig' backend/ --include='*.go'          # → 仅 pkg/conf/config.go:3 的注释，0 处代码

# 序2 的两道闸（§18.3 障碍 2 / §20.3）：这两个函数此前都是零调用方
grep -rn 'conf\.Reload()' backend/ --include='*.go'      # → 1 处：utils/admin_runtime_config.go:307（序2 前为空；第十一批前是 :76）
grep -rn 'conf\.LoadFile(' backend/ --include='*.go' | grep -v 'backend/pkg/conf/'
#   → 5 处：migrate-media-oss:31 · temp-mail-password:51,52 · moesocial/startupconfig.go:58 · admin_runtime_config.go:352
# -f 权威性的常驻回归测试（该测试在 HEAD 上 FAIL，见 §20.3）
go test ./internal/platform/moesocial/ -run TestUnifiedFlagIsAuthoritativeForAllReaders
# 序2.5 的两条闸门（§21.3 / §21.4）：第 1 条在 4f51845e 上 FAIL（StorageDir = ""），
# 因为那时 viper 读不到文件会让整个 ApplyUnifiedConfigOverrides 提前 return
cd backend && go test ./internal/platform/wiring/ -run 'TestOverrides' -v
# §20.5 / §22.6：仍然看不见 -f 的文件（各自硬编码 searchDirs）→ **0**（第九批前是 10）
# ⚠️ 对照组同样不能写 HEAD：c083ce8a 已含第九批，HEAD 版返回 0，与被测值相同 → 对照失效。
#    实测四个提交：14370f93 = 13 · bec11b26 = 13 · 4f51845e = 10 · c083ce8a = 0。
#    钉 4f51845e（= §20.5 标题里那个「10 个文件」的出处）；钉 14370f93 则是 13。
grep -rln 'AddConfigPath("\.\./\.\./config")' backend/ --include='*.go' \
  | grep -v '_test.go' | grep -v 'backend/pkg/conf/' | wc -l              # → 0
git grep -l 'AddConfigPath("\.\./\.\./config")' 4f51845e -- 'backend/*.go' \
  | grep -v '_test.go' | grep -v 'backend/pkg/conf/' | wc -l              # → 10（对照组，钉在第九批之前）
# §19.4 / §21.1：apiconfig 缺 mapstructure tag（41 json / 0 mapstructure 这个事实没变，
# 但序2.5 之后它**不再是隐患**——apiconfig 结构已经不当 mapstructure 的解码目标了）
grep -ohE '`(json|yaml|mapstructure):' backend/internal/platform/apiconfig/*.go | sort | uniq -c   # → 41 json / 0 mapstructure
# 真正的闸门是这条：非生成代码里 UnmarshalKey 的**实际调用点**必须为 0
grep -rn 'UnmarshalKey' backend/ --include='*.go' | grep -v '_test.go' | grep -v 'backend/api/' | grep -v 'backend/deploy/'
#   → 只剩 config_override.go 注释里的一处提及，0 个调用点
# §19.4 的死链路复核（离线模型功能未接线，删或接线属产品决定，见 §21.5）
grep -rn 'ListLlmLocalModelsCatalog' backend/internal/ backend/cmd/ --include='*.go'   # → 0 实现
grep -rn 'LoadLocalModelCatalog\|FindLocalModelByID' backend/ --include='*.go' | grep -v 'apicomm/local_models.go'   # → 0 外部调用方
grep -rn 'local-models\|local_models\|localModels' lib/                                # → 0

# §17.6(a) / §22.6：gofmt 闸门（make check 既不跑 gofmt 也不跑 vet）
gofmt -l backend/ | wc -l                       # → 127（§17.6 原记的 92 与第九批中途记的 94 都是错的）
git ls-files 'backend/*.go' | wc -l             # → 928，即 127/928 个跟踪文件不洁
gofmt -l backend/ | grep -c '\.pb\.go'          # → 0，全部是手写代码，不能推给生成器
# ⚠️ 这两条必须在**仓库根**跑。在 backend/ 里执行 git ls-files 'backend/*.go' 时，
#    pathspec 相对当前目录解析成 backend/backend/*.go → 空列表 → xargs gofmt -l 读 stdin
#    → 输出 0，是一个**看起来像「全部格式正确」的假清白**（第九批当场踩过）。
# 本批是否新增不洁文件：把改动文件与不洁集合求交集，再逐个和 HEAD 版比 gofmt -d
git status --porcelain | awk '{print $2}' | grep '\.go$' | sort > /tmp/changed.txt
comm -12 <(gofmt -l backend/ | sort) /tmp/changed.txt        # → 仅 pkg/moe/brain/refine.go
git show HEAD:backend/pkg/moe/brain/refine.go > /tmp/a.go && gofmt -d /tmp/a.go   # 差异逐字节相同 ⇒ 既有

# §22.6：差分启动（「确保每一次调整完程序都正确可运行」这条标准的实测手段）
# 1) 两侧各建一个二进制；HEAD 侧用 worktree，避免污染工作区
cd backend && go build -o /tmp/moe-work ./cmd/moe-social
git worktree add --detach /tmp/moe-head-wt HEAD
cd /tmp/moe-head-wt/backend && go build -o /tmp/moe-head ./cmd/moe-social
# 2) 同一工作目录、同一 -f，各启动 25 秒（真配置连的是测试库，见 §0 第 13 行）
cd <repo>/backend && /tmp/moe-work -f config/config.yaml > /tmp/boot_new.log 2>&1 &
#    ……sleep 25; kill；对 /tmp/moe-head 重复一次……
# 3) 归一化后逐行比对：剥时间戳、GORM 耗时、SQL 里的时间字面量、ANSI 色码
#    预期唯一差异 = GORM 打印的编译期源文件路径（worktree 路径）+ 活动数据表的行数
#    必须逐行相同的关键行：「── HTTP 域装配 ──」下面那条 22 个域的清单、
#    「图片: dir=… public=… max=…」、「moe bot/dream scheduler started tick=…」、
#    「moe-social ready: Kratos HTTP-only on port 8888」
# 4) -f 权威性正向探针：造一份只在 tick 上与真配置不同的文件（合成非零值 7/11，
#    既不同于真配置的 60/300，也不同于代码缺省的 60/300），在 backend/ 目录里启动
sed -e 's/bot_scheduler_tick_seconds: 60/bot_scheduler_tick_seconds: 7/' \
    -e 's/dream_scheduler_tick_seconds: 300/dream_scheduler_tick_seconds: 11/' \
    config/config.yaml > /tmp/probe.yaml
/tmp/moe-work -f /tmp/probe.yaml    # 日志须打出 tick=7s / tick=11s，而不是同目录 ./config 的 60/300
#    HEAD 侧不必再启：它的 runtime/config_load.go、brain/dream_schedule.go、moewiring/config.go
#    各自 viper.New() + SetConfigName("config") + 三个 AddConfigPath，-f 的值没有传入通道（静态可判定）
# 5) 清理并**验证**清理（worktree、二进制、进程、端口四项都要查）
git worktree remove /tmp/moe-head-wt --force && git worktree prune && git worktree list
rm -f /tmp/moe-work /tmp/moe-head /tmp/probe.yaml
pgrep -fl 'moe-work|moe-head'; lsof -nP -iTCP:8888 -sTCP:LISTEN
# ⚠️ 每次真实启动都会往 life_items 插 6 行重复道具（§22.7 / §0 第 17 行），差分启动前先记住基线行数
```

---

## §23 2026-09-11 第十批：文档对齐 —— 24 处失真逐条处置（含 3 条前提被实测推翻）

§0 第 18 行两次前向引用本节。补上，否则就是本审计自己在制造悬空引用。

### 23.1 方法与口径

审计对象是**文档对代码的陈述**，判定标准只有一条：**照着文档做会不会失败，或会不会得出错误结论**。
因此「措辞过时但结论仍成立」不算失真，「措辞漂亮但行号指错」算。

每一条都做了三件事，缺一即不采信：

1. **正向核实**——文档说的那个东西现在是什么（读代码，不读别的文档）；
2. **负向核实**——文档说的那个东西是否真的不存在（`git grep` / `ls` / `git ls-files` 零命中，而不是「我没找到」）；
3. **可执行性核实**——文档给出的命令**实际跑一遍**，看它是否真的失败、以什么方式失败。

第 3 步是本次最有价值的一步：它推翻了我自己此前记下的三条判断（见 §23.3）。
只靠 grep 的审计会把「文档说 A，代码里是 B」直接判成失真，而不去问「A 会不会在某个我还没看的上下文里是对的」。

### 23.2 逐条处置（23 个文件，24 处失真 + 5 处新发现）

| # | 位置 | 原文陈述 | 实测 | 处置 |
|---|---|---|---|---|
| 1 | `.cursor/rules/moe-social-engineering.mdc:336` | `go run ./cmd/moe-social/ -conf ./config` | `cmd/moe-social/main.go:18` 只定义 `-f`；`-conf` 仅存在于 `cmd/migrate-media-oss/main.go:26` | 改为 `-f config/config.yaml`。**本条最严重**：该文件 `alwaysApply: true`，是每个 agent 都会读的工程规则 SSOT，照抄必报 `flag provided but not defined: -conf` |
| 2 | 同上 R07（`:260-263`） | 「走配置文件（`backend/config/`）或环境变量」 | 没说**怎么读**，而第九批后读取入口已唯一 | 补一条硬规则：只走 `pkg/conf`，禁止业务层 `viper.New()` 与内联 `"<段>.<子键>"` |
| 3 | `docs/dev/moe-social-runtime.md:42` | 启动顺序首步 `utils.InitConfig()` | 全仓无此函数；实为 `run_http_only.go:19` 的 `conf.Load()` | 按代码逐行重写，补 `NormalizeOptions` 与 `externalHTTPPort`，标出行号 |
| 4 | 同上 `:29` | 成功日志在 `run_http_only.go:49` | `:49` 是函数声明行，`log.Printf` 在 `:50` | 改为 `:50` |
| 5 | 同上 `:27` | 记录了 `-f` 但未提它此前对一部分键无效 | 第九批已清零（searchDirs 文件 10 → 0） | 转为**正向陈述**：`-f` 现为进程级唯一权威，附 `tick=7s/11s` 探针证据 |
| 6 | 同上 `:14` | 配置 SSOT 只写文件位置 | 缺读取层 | 补 `pkg/conf` 与三个示例函数 |
| 7 | `moe-admin/README.md:11,14,15` | `make dev`；`make moe-social` **默认含** deploy-agent | `make dev` 与 `cmd/dev/` 均不存在；`make moe-social` = `go run ./cmd/moe-social`（`Makefile:66-67`），**不带** agent | 三行重写。自动生成 `deploy/config.yaml` 的行为在 `cmd/deploy-agent/main.go:28-36`，只有 `make deploy-agent` 触发 |
| 8 | `docs/dev/kratos-p5-split-deploy.md:10` | 「仍然活着的只有三个闸门」，出处 `moeconf/load.go:76-77`、`moewiring/config.go:141` | `moeconf` 整包已删；`register_moe_grpc` / `use_moe_grpc` **全仓零命中**；`SuperGrpcRetired()` 已删（仅 `config.go:32-35` 一行墓碑）；唯一活着的是 `moe.single_process` | 横幅改写为实测结论。横幅是历史文档唯一会被读的部分，必须准 |
| 9 | 同上 `:103-107` | `make build` 产 api+rpc；`make split-deploy-smoke`；`grpcsmoke` 包 | `make build` 只产 `bin/moe-social`；该 target 不存在；该包目录不存在 | 标题加「**全部已失效，勿执行**」，逐行标 ✗。这是全文唯一「像是能跑」的代码块 |
| 10 | `docs/dev/ports.md:26,27` | 18888/19032 仅存于 `moewiring/config.go:169`/`:184,189` 兜底 | 该文件现 49 行，两处兜底随 15 个过渡开关同批删除 | 状态升级为「**残留已清除**，全仓零命中」——比原文更强 |
| 11 | 同上 `:28,34,35` | `config.yaml:103` / `:97` / `:253-259` | 实为 `:97` / `:91` / `:244-252`（第九批删死键导致整体上移） | 三个行号改正，并加「读取入口」列 |
| 12 | `CODE_WIKI.md:253` | `llm_inference` 默认 DeepSeek | `config.yaml:89-94` 是 `provider: ollama` + `192.168.124.77:11434` + `qwen2.5:3b-instruct`；DeepSeek 只剩 `:102` 一行注释 | 改写为生效值 |
| 13 | 同上 `:254` | `moe.kratos_pure_enabled: true` | 该键 2026-09-08 删除、零读者 | 换为 `single_process` + 19 个域开关的继承语义，并列出已删的过渡键 |
| 14 | 同上 `:12` | 只提 `MOE_LLM_API_KEY` | `derive.go:16-25` 认四个，第九批后作用域统一 | **不改写 2026-06-29 的历史快照**，另加一份 2026-09-11 摘要并显式指出旧摘要已过期 |
| 15 | 同上 `:265` | `make moe-social-dev` = 后端 + deploy-agent | 实为 `moe-social-stack -agent=false` | 改正，并给 `make check` 加上「不跑 gofmt/vet」的警示 |
| 16 | `docs/dev/new-api-kratos.md:38` | 目录树含 `moeconf` | 该目录不存在；同时漏了 `appdb`/`yamlconf`/`moelog`/`chatdelivery`/`socialhook` 五个实际存在的包 | 按 `ls` 重写，标注 `pkg/conf` 不在 platform 下。`27 个域` / `28 处 Register*HTTPServer` 经 `ls`+`grep -c` 复核**无误**，未改 |
| 17 | `docs/dev/security-and-stability-backlog.md:44` | `auth_jwt_config.go:26` `ConfigureJWT`；由 `config_override.go:113` 加载 | `ConfigureJWT` 在 `:22`；`config_override.go` 全文 125 行且 `:113` 是 `}`；真正调用方是 `wire_svc.go:24`，`:96` 只做 env→struct 合并 | 三个位置全部改正 |
| 18 | 同上 `:77` | ⚠️ `auth.access_secret` 缺失**不会**导致启动失败（引 `:65-72`） | **结论整个反了**：见 §23.3(1)。且 `:65-72` 不存在（全文 47 行），`jwtSigningKey()` 在 `:39-46` | ⚠️ 改为 ✅，附完整传播链；原文建议的「改为启动期强校验」标注为**已无需再做** |
| 19 | 同上 `:42-49` | 「本轮已处理（2026-05）」表引用 5 个文件 | `ai_resource_helpers` / `ai_resources_logic` / `resource_logic` / `userconfiglogic` / `chatlogic` 经 `git ls-files` 核实**全部不存在** | 整节加历史归档横幅（新发现，原 24 条未含） |
| 20 | `docs/dev/admin-rpc-runtime-guide.md:16` | `Makefile:69-70` | 实为 `:66-67`；`:69-70` 现在指向注释行与 `moe-social-dev`——恰好复现这张表要纠正的混淆 | 改正并顺带点明 `:70-71` 才是 stack |
| 21 | `.cursor/skills/ollama-mini-host/SKILL.md:30` | 示例 YAML 用 `model: qwen3:4b` | **`llm_inference.model` 不是键**（`config.go:120-130` 只有 `memory_model`/`chat_model`/`game_model`）→ 静默落空、无任何报错 | 改为 `memory_model` 并加显式警告；`:96` 的排查步骤也补上正确键名 |
| 22 | 同上 `:39` | `internal/adapter/moeconfig/inference.go` 读取统一配置 | 整包 2026-09-09 删除 | 改为 `pkg/conf/derive.go` |
| 23 | 同上 `:84` | `go test ./pkg/llminference/... ./internal/adapter/moeconfig/...` | **实跑确认失败**：`lstat ./internal/adapter/moeconfig/: no such file or directory` + `[setup failed]` | 改为 `./pkg/conf/...`，实跑确认两包均 `ok`；把失败信息留在注释里供比对 |
| 24 | `docs/dev/moe-admin-platform-design.md:54` | 可配置 `admin.session_expire_hours` | 无此键；实为 `admin.token_expire_hours`（`config.yaml:25`，当前 168），入口 `conf.AdminJWT()` | 改正并加「没有 session_expire_hours 这个键」的显式否定 |
| 25 | 同上 `:3` | 技术栈钉死为 go-zero + RPC + ops-console | 三者全部过期；3 处 `@server(group:)` 是 go-zero IDL；`/api/admin/captcha` 在 proto 中零命中 | 加历史设计稿横幅，指明哪些部分仍可参考 |
| 26 | `docs/dev/用户级记忆统一改造验收脚本.md:68` | 第 4 步关闭 `memory.search.hybrid_enabled` | 零读者（`pkg/conf/config.go:20` 记名死配置）→ 该步永不生效 | 见 #27，本条被更大的发现吸收 |
| 27 | 同上 `:66-67`、`:72,76` | Case G/H 调 `memories/reindex`、`memories/search`、`POST/GET /memories` | **路由有、实现无**：见 §23.3(3) | Case G 整节标为「已下线，无法执行」，原步骤收进 `<details>`；Case H 逐步标 ✗/✅（只有 `/devices` 属 user 域、仍可验证） |
| 28 | `docs/dev/用户记忆系统-OpenClaw式演进设计.md:4,108,113,120` | PostgreSQL；`HybridSearchUserFacingMemories` / `HybridSearchEnhanced`；`ollama.base_url` + `memory.embedding.ollama_model`；`providers[]` | 实为 MySQL（`postgres` 在 backend 的 `.go`+`go.mod` 零命中）；两函数全仓不存在；`ollama_model` 根本不是键（`config.yaml:237-240` 只有 openai_*）；无 `providers[]` | 加逐项实测对照横幅。**本文自称「唯一事实源，禁止并行多套方案」，此类文档失真危害最大** |
| 29 | `docs/dev/Moe-Intelligence-Stack-v1.md:85` | 未配置 Agent 时按 `moe.default_capability_tier` | 该键**零读者**（`config.yaml:171` 写着 s2 但没人读；~~原记 `:184`~~，`local_models` 整块 13 行在 #42 被删后**上移**到 `:171`）；真实默认是编译期常量 `core.DefaultTier = TierS2`（`tier.go:16`），`ParseTier` 的 default 分支同样返回 S2 | 改为编译期常量，并加「改 config.yaml 无效」的警告。档位工具表也与 `AllowsTool`（现 `tier.go:38-51`；~~原记 `:32-45`~~，§29 摘掉三个幽灵工具名后下移）不符，一并按代码补全。**但本行「按代码补全」的处置只对了一半**：§29 发现该文档 §4 的工具清单列了 **5 个从不存在的工具**，其中 2 个还被注明「由 Flutter 本地处理」，而那条 Flutter 链路整条不存在 —— 详见 §29.5 |
| 30 | `backend/docs/private_messages.md:30` | 「RPC 启动时已 `InitConfig` 可读」 | `backend/rpc/` 不存在、`utils.InitConfig` 无此函数。但**配置本身是活的**：`utils/private_message.go:15` 读 `conf.Get().PrivateMessage` | 换成实测读取链（`run_http_only.go:19` → `utils/private_message.go:15`） |
| 31 | `docs/testing/E2E测试清单.md:6-7` | 前置：`backend/api` 已启动；`backend/rpc` 已启动 :8080 + `SuperRpc` 可连通 | `backend/api` 是 proto 目录不是进程；`backend/rpc/` 不存在、:8080 无监听、`SuperRpc` 与相关键已删 | 改为 `make moe-social` + `curl /health`，并明确「不存在后端 RPC 这一前置，不是环境搭错」 |
| 32 | `README.md:84,92-93` | `make build # 或分别启动 api / rpc`；`docker logs moe-social-api` / `-rpc` | compose 只有**一个** service，`container_name: moe-social`（`docker-compose.binary.yml:3-6`）→ 那两条 `docker logs` 必得 no such container；且无 `build:` 段，`--build` 是空操作 | 改正，并补上被漏掉的依赖关系：compose 挂载 `./bin/moe-social`，故 `make build` 是**前置**步骤 |
| 33 | `.cursor/LESSONS.md:10` | 跑 `backend/scripts/gen-moe-admin.sh`（若存在） | 实为 `backend/scripts/gen/moe-admin.sh`（在 `gen/` 子目录）；且有 `make gen-moe-admin` target | 改为 make target（脚本路径再变也不会失效）。「若存在」这种含糊措辞放在踩坑清单里等于没给答案 |
| 34 | `docs/dev/llm-inference-and-memory-vision.md:3,10,11,13` | 「本机 llama-server（OpenAI 兼容）」；`base_url` 如 `:6633`；`api_style` 默认 openai；片段「与 Ollama 旧键已统一」 | 生效值是局域网 Ollama；片段里的 `:6633`/`openai`/`300` 会被 `config.yaml:89-94` 覆盖（`config_override.go:21-33`）；`apiconfig` **没有** `Ollama` 字段，片段层无从「统一」 | 重写：把**生效值**与**片段默认值**分开，补 `conf.Inference()` / `ResolveInference()` / `GameInference()` 三者区别与四个 env |
| 35 | `backend/LAYOUT.md` 全文 | 目录树 | **整份文档零次提到 `pkg/`**，而 `pkg/conf` 有 49 个反向依赖；`internal/platform/` 只列了 12 个实际子目录中的 6 个 | 补整个 `pkg/` 层（`pkg/conf` 三个文件职责逐一写明）+ 6 个漏列子目录 + `utils`/`model`/`deploy`，并加「新增配置项该改哪里」。**这是本批唯一的结构性修补** |
| 36 | 同上 `:3` | 更新 2026-08-06；「运行」段无 `-f` | — | 更新日期；补 `-f` 用法与「不是 `-conf`」的对照 |
| 37 | `docs/dev/n100-pipeline.md:44` | 第 3 步访问 `:8888/migration` | 该路由已删（`git grep '"/migration"'` 零命中）→ 404，会被误判成部署失败 | 改为 `/health`（`http.go:36` 直挂）+ `/kratos/v1/moe/runtimes` |
| 38 | `code_review.md:29` | Backend 检查 `backend/api/super.api`、`backend/rpc/super.proto` | 两者均 `No such file or directory`；「handler and logic layers」是 go-zero 术语，现行分层是 `service → biz → data` | 改写为现行契约与门禁（新发现，原 24 条未含）。**推荐进清单的 `go build ./...` 与 `go vet ./...` 已实跑确认 rc=0/0 行** |
| 39 | `docs/dev/README.md:13,46,48` | 「6 批整改路线」；OpenClaw 文标为「**记忆架构 SSOT**」；`memory/README.md` 标为「代码模块地图」 | 已九批；那两篇文档自身都带「已整体移除」横幅，索引却当作活文档推荐 | 索引行补状态标注（索引是读者最先扫的地方，警示只放正文等于没放），并**新增一行指向 `backend/LAYOUT.md`**——此前索引里没有任何条目指向配置读取 SSOT |

### 23.3 三条前提被实测推翻（本节最重要的部分）

审计清单是上一轮用 grep 得出的。本轮逐条实跑后，**三条判断错了**。记下来，因为错的方向各不相同，各自对应一类陷阱：

**(1) `security-and-stability-backlog.md:77` 的 ⚠️ 警告，结论整个是反的。**
原文断言「`auth.access_secret` 缺失**不会**导致启动失败，进程照常起来、`/health` 照常 200」，并据此建议「改为启动期强校验」。
实测传播链：`api/etc/moe.yaml:8` 的 `AccessSecret` 默认空串 → `ConfigureJWT` 对空值返回 error（`utils/auth_jwt_config.go:24-26`）→ `wire_svc.go:24-26` → `wiring/server.go:26-28` → `run_http_only.go:29-32` 包成 `wire: %w` → `cmd/moe-social/main.go` `log.Fatal(err)`。
**空密钥会让进程起不来。** 原文描述的隐患不存在，它建议的加固**早已实现**。
陷阱类型：**只读了函数本身，没追调用方对返回值的处置**。`jwtSigningKey()` 确实是请求期检查，但它是第二道防线，不是唯一一道。

**(2) `docs/dev/llm-inference-and-memory-vision.md:15` 的「`ollama.*` 仅作读取兼容」——原判为「第九批后失真」，实际仍然成立。**
`ResolveInference()` 的 `ollama.*` 回退还在（`derive.go:55` 的 `o := Get().Ollama`），第九批只是把它的读者收敛到一个，并没有删掉它。
该文档真正过期的是**别处**：头部把生效端点说成本机 llama-server，以及「片段与 Ollama 旧键已统一」——`apiconfig` 里根本没有 `Ollama` 字段，无从统一。
陷阱类型：**把「某个说法所在的文档有问题」当成了「这个说法有问题」**。同一页里对错混杂，必须逐句判，不能逐页判。
（附带更正：上一轮记录「`ollama.*` 回退可删」仍然成立，但它属 §22.8 未处置项，与本文档失真无关，两件事不要混记。）

**(3) `docs/dev/n100-pipeline.md:20` 说生产入口是 `cmd/moe-social-stack`——原判为「与 `cmd/moe-social/main.go:1` 矛盾」，实际该文档是对的。**
决定性证据是 `deploy/n100/moe-social.service:9`：`ExecStart=... -agent=false`。而 `-agent` **只有 `moe-social-stack` 定义**（`cmd/moe-social` 只有 `-f`/`-f-api`/`-migrate`），换成 `cmd/moe-social` 会直接 `flag provided but not defined: -agent`。`.github/workflows/n100-deploy.yml:37` 编 stack 是**必须的**。
真正的问题不在文档，在代码：**预发与生产编的不是同一个入口**（n100 → `moe-social-stack`；`make build` / `make build-linux` / compose → `moe-social`）。文档已改写为明确区分两者并标注这个分歧风险。
陷阱类型：**在两个文件之间看到矛盾就判定其中一个错，没去找第三个文件（部署单元）来裁决**。

### 23.4 审计过程中新发现的 5 条（原 24 条之外）

| # | 发现 | 证据 | 性质 |
|---|---|---|---|
| a | **`make moe-social-dev` 被三处文档写成「+ deploy-agent :19010」，实际显式关闭** | `Makefile:70-71` = `go run ./cmd/moe-social-stack -agent=false`；`cmd/moe-social-stack/main.go:25` 的 `-agent` 默认值也是 `false` | 已修（工程规则、moe-admin README、CODE_WIKI 三处）。**同一个错误出现在三个文件里，说明它是被互相抄来的**，不是三处独立笔误 |
| b | **用户记忆 HTTP API 是「已路由但未实现」的死接口面** | `POST/GET/DELETE /api/user/{id}/memories`、`/memories/search`、`/memories/reindex` 由 `llm_messages_http.pb.go:59-66` 挂上路由，但 `http_proto.go:183` 注册的 `protohttp/llm.Server` 内嵌 `UnimplementedLlmChatServer` 且**只实现了 `GetAiUserConfig` / `UpsertAiUserConfig`**（`internal/server` 与 `internal/service` 下 `memories` 零命中）→ 返回 `codes.Unimplemented`。**Flutter 与 moe-admin 均无调用方**（Flutter 的 `memories` 命中的是 companion 记忆，另一套子系统） | **代码问题，非文档问题**。属 2026-06-29 删向量记忆后的残留 proto。处置需产品决策：清 proto 还是重做实现 → 记为待决，本批未动代码 |
| c | **`security-and-stability-backlog.md` 的「已处理（2026-05）」表引用 5 个已不存在的文件** | `git ls-files` 对 `ai_resource_helpers` / `ai_resources_logic` / `resource_logic` / `userconfiglogic` / `chatlogic` 全部零命中 | 已加历史归档横幅 |
| d | **`code_review.md` 的 Backend 检查项指向两个不存在的文件** | `ls backend/api/super.api backend/rpc` → 均 `No such file or directory` | 已改写。这条比看上去严重：**review 清单是会被自动执行的**，失效项会让 reviewer 误判 PR 缺文件 |
| e | **`docs/dev/README.md` 索引把两篇自带「已整体移除」横幅的文档当作活文档推荐**，且索引里没有任何一条指向配置读取 SSOT | `:46` 标 OpenClaw 文为「记忆架构 SSOT」、`:48` 标 `memory/README.md` 为「代码模块地图」，两篇文首横幅都写明目录已不存在；`pkg/conf`（49 个反向依赖）在索引中零条目 | 已补状态标注 + 新增指向 `backend/LAYOUT.md` 的一行 |

### 23.5 刻意**不**改的 4 处（含 1 处差点被误修）

| 位置 | 为什么不改 |
|---|---|
| **`docs/dev/media-oss-migration.md:51,54`** 的 `-conf ./config` | ✅ **这里的 `-conf` 是对的**。`cmd/migrate-media-oss/main.go:26` 确实定义了 `flag.String("conf", "./config", ...)`。它与第 1 条的区别是**入口程序不同**，不是文档对错不同。修它就是制造一个新的失真——这是全批最容易犯的一个错，因为「`-conf` 是假 flag」已经成了本轮的思维定势 |
| `docs/product/签到等级管理后台系统实施文档.md` | 文首已有合格横幅（写明 `make gen-api`/`gen-rpc` 已删、目录已移除、照做会失败，并给出 Kratos 现行做法与 `checkin.proto` 落地位置）。再加一层是噪音 |
| `docs/dev/memory/README.md` | 同上，文首横幅已逐项写明三个目录不存在、四个函数零命中。**但它在索引里的标签是误导的**——所以修的是索引（§23.4(e)），不是正文 |
| `.cursor/rules/backend-ai-spec.mdc:28`、`moe-social-engineering.mdc:81` | `backend/rpc` 出现在**「禁止」清单**里（「均已退役」），陈述正确。grep 命中不等于陈述错误 |

### 23.6 一个未处置的仓库卫生问题：`moe_social_backend/`

工作区里有一个 `moe_social_backend/` 目录（160K，`git status` 中为未跟踪）。本轮查明它的性质：

- 它是**一个独立的 git 仓库**，不是散落文件：含完整 `.git/`，`remote origin = git@github.com:xuxinzhi007/moe_social_backend.git`，历史仅一条 `bc17706 first commit`；
- 工作文件只有一个 `README.md`，且**处于已修改未提交状态**（`M README.md`）；
- 该 README 是根 README 的一份陈旧副本：含同样的 api/rpc 双进程措辞，另有 218-246 行描述一个**不存在的 `app-rn/` 目录**与六个**不存在的 make target**（`rn-install`/`rn-start`/`rn-tunnel`/`rn-android`/`rn-web`/`rn-typecheck`；根 `Makefile` 只有 `backend-gen`/`backend-check`/`backend-dev`/`backend-migrate`/`help`）。

**处置建议：整个目录删除**（它是独立仓库、有远端，删掉本地副本不会丢失任何未推送内容——但那处 `M README.md` 是未提交改动，删之前应先确认）。
**本批未动它**：它未被外层仓库跟踪、且带有未提交修改，可能是正在进行的工作。按「不擅自删除疑似用户在制品」的原则，只登记、只上报。

### 23.7 验证

| 项 | 结果 |
|---|---|
| 改动文件数 | **24 个 `.md`/`.mdc`**（23 个文档 + 本节）。未改任何 `.go` 文件——本批是纯文档批次 |
| 后端门禁 | `go build ./...` rc=0 / 0 行；`go vet ./...` rc=0 / 0 行（两条命令都是本批**新写进 `code_review.md` 的**，故先实跑确认可用再落笔） |
| 文档中新给的命令 | `go test ./pkg/llminference/... ./pkg/conf/...` 实跑两包均 `ok`；旧命令实跑确认 `[setup failed]`（正负对照都有） |
| `-conf` 残留复查 | 全仓 `.md`/`.mdc` 中 `-conf ./config` 仅剩 `media-oss-migration.md:51,54` 两处，**均为正确用法**（见 §23.5） |
| `InitConfig` 残留复查 | 仅剩 `private_messages.md:30` 一处，且是「已过期」的否定式引用 |
| `moeconf` / `moeconfig` 残留复查 | 6 处，全部为「已于某日删除」的历史框定，无一处陈述为现状 |
| **`pkg/conf` 文档覆盖** | **1 → 14 个文档**（此前全仓只有 `backend/docs/dev/kratos-intentional-transport.md:38` 提到过）。这是 §0 第 18 行「没有任何文档提到 `pkg/conf`」的收口证据 |
| 悬空引用 | §0 第 18 行的两处 `§23` 已由本节兑现 |

### 23.8 未处置（登记）

- §23.4(b) 的死接口面：需产品决策（清 proto vs 重做实现），涉及生成物与契约，不单方动。
- §23.6 的 `moe_social_backend/`：需确认那处未提交的 `M README.md` 后再删。
- `docs/dev/应用配置与全局常量分层约定.md`：本轮复核为**准确**（已在清洁名单内），但它是 Flutter 侧分层约定，与后端 `pkg/conf` 的关系尚无一处文档说明。属「缺一份对照」，不属失真，未动。
- 各文档的「最后更新/最后核对」戳此前普遍滞后于内容（`ports.md` 标 09-08、`LAYOUT.md` 标 08-06、`CODE_WIKI.md` 标 06-29、`p5` 标 05-29）。本批已把改过的都推进到 09-11，但**这不是一个能靠人工维持的机制**——真正需要的是 CI 里一条「文档引用的文件/行号是否存在」的断言，尚未建。

---

## §24 2026-09-11 第十一批：对抗式自审 —— 第八/九/十批留下的 4 个隐藏缺陷 + 1 个门禁失效

### 24.1 触发条件与结论

第十批把有效收敛率推到 100% 之后，本批不再向前推进，而是**回头审自己的改动**：假设批次八/九/十里存在我引入或漏掉的 bug，逐个证伪。结论是这个假设成立——找到 4 个真缺陷 + 1 个让 `-race` 对全仓失效的测试替身缺陷，其中 **#34 是破坏性的**（管理台点一次「保存」就会抹掉一个被 git 跟踪的文件里全部 79 行注释）。

四个缺陷有一个共同形状：**批次九把「`-f` 是进程级唯一权威」证成了，但只证了读路径**。写路径（管理台保存）和缓存失效路径（`Reload`）都还各自为政，于是「逻辑闭合」在读写交汇处断开。这正是「grep 命中 ≠ 消费方」「编译通过 ≠ 生效」之外的一条：**单向证明 ≠ 闭合**。

| 编号 | 缺陷 | 严重度 | 状态 |
|---|---|---|---|
| #31 | `conf.Reload()` 先清缓存再读盘，窗口内并发 `Get()` 落到 `searchDirs` 而非 `-f` | 高（部署相关） | 已修 + 判别性测试 |
| #32 | `resolveUnifiedConfigPath()` 无视 `conf.Path()`，写回与读取认的不是同一个文件 | 高 | 已修 + 判别性测试 |
| #34 | 管理台保存走 `viper.WriteConfig()`，销毁全文注释并静默改类型 | **最高（破坏性）** | 已修 + 判别性测试 |
| #35 | `MoeProduction` 建模了不存在的 gRPC/pilot 拓扑（4 个死字段） | 低（文档一致性） | 已删 |
| #36 | `companion.fakeStore` 无锁，`-race` 报 3 处 DATA RACE | 中（门禁失效） | 已修 |

#33（40 键迁移的默认值反转审计）结论是**无反转**，见 §24.6。

### 24.2 #31 `Reload()` 的未加载窗口（实测 0.25 秒内 459501 次错值读取）

旧实现：

```go
mu.Lock(); path := current.path; current = nil; autoFailed = false; mu.Unlock()
return LoadFile(path)
```

`current = nil` 与 `LoadFile` 换入新 state 之间是一个**横跨一次完整读盘**的窗口。窗口内并发的 `Get()` 看到 `current == nil` 且 `autoFailed == false`，于是走 `loadLocked() → resolvePath()`——而 `resolvePath` 认的是包级 `searchDirs`（`./config`、`../config`、`../../config`），**不是 `-f` 指定的路径**。

后果取决于部署，这也是它一直没被发现的原因：

- n100 用 `-f config/config.yaml`，与 `./config/config.yaml` 恰好是同一个文件 → 窗口内读到的还是对的，**看不出来**；
- 自定义 `-f`（例如 `-f /etc/moe/prod.yaml`）→ 窗口内读到 `./config` 那个**另一个**文件；
- cwd 下没有 `config/` → `resolvePath` 失败，`Get()` 返回零值 `Config`：**`DSN()` 返回空连接串、`AuthAccessSecret()` 返回空密钥**。

实测：`TestReloadNeverExposesUnloadedWindow` 起 8 个读者 goroutine 猛读 `Get().Runtime.HTTPPort`，主 goroutine 做 1000 轮 `Reload()`；在旧实现下 **0.25 秒内观测到 459501 次错值读取**。测试 chdir 到一个四层深的临时目录，使三个 `searchDirs` 候选全部不存在，于是窗口内的错值必定是零值、必定可观测——这是判别力的来源，不是运气。

修复：`Reload()` 不再清空 `current`。`LoadFile` 本来就无条件重读并在写锁内**整体换入一个新的 `*state`**（含新的 `*Config`），旧指针从不被就地改写，所以并发读者要么看到旧快照要么看到新快照，不存在撕裂。

### 24.3 #32 写回路径无视 `-f`：读写两条路径对「哪个文件是权威」答案不一致

`utils/admin_runtime_config.go` 的 `resolveUnifiedConfigPath()` 旧实现只在 cwd 下试三个硬编码候选，**从不查 `conf.Path()`**。于是：

- **读**路径 `ReadRuntimeConfig()` → `conf.Reload()` → `current.path`：**尊重 `-f`**；
- **写**路径 `ApplyRuntimeConfigPatch()` → `resolveUnifiedConfigPath()` → `./config/config.yaml`：**不尊重 `-f`**，写完还调 `conf.LoadFile(那个路径)`，把**整个进程**的配置源在运行时劫持到另一个文件去。

这不是理论路径，是一个活的管理台端点：`PUT /api/admin/runtime-config`（路由在 `api/admin/v1/admin_messages_http.pb.go:258`，处理在 `internal/server/protohttp/adminapp/adminapp_legacy.go:222`），GET 侧在 `:207` 与 `internal/biz/admin/insights.go:116`。

批次九刚刚证成「`-f` 是进程级唯一权威」，而这条写路径正是它的反例。修复后 `conf.Path()` 是第一顺位，三个 cwd 候选只在 conf 尚未成功加载时（例如配置文件本身损坏）兜底。

活进程实测见 §24.9：`config_file` 字段返回 `/tmp/dashf/custom.yaml`，PUT 只改了那个文件，被跟踪的 `backend/config/config.yaml` **md5 不变**。

### 24.4 #34 管理台保存会销毁 `config.yaml` 全部 79 行注释（本批最严重）

旧实现是 `v := newUnifiedConfigViper(); v.Set(...); v.WriteConfig()`。`WriteConfig` 从 viper 的内部 map **重新序列化整个文件**，而那个 map 里没有注释、没有空行、没有原始缩进、也没有原始类型。在真实的 `backend/config/config.yaml`（10073 字节 / 265 行 / 79 行注释 / 122 个叶子键）上实测：

| 写法 | 实测结果 |
|---|---|
| `viper.Set` + `WriteConfig()`（**旧实现**） | 10073→**4416** 字节、265→**154** 行、79 行注释→**0 行注释**；122 个叶子键都还在、类型化 `Config` 逐字段相同、`IsSet` 漂移 0；但 `memory.search` 的 3 个 float 被**静默降级成 int**（`vector_weight` / `graph_boost` / `keyword_weight`） |
| `yaml.Unmarshal`→Node→`yaml.Marshal(&node)`（**第一次尝试，也失败**） | 注释保住了，但缩进 2 空格→4 空格、空行全删、`432000  # 5 天` 被压成 `432000 # 5 天` → **418 行 diff** |
| **按字节定点改行（最终实现）** | 每处改动 **1 行 diff**；活进程 2 处改动 = 2 行 diff，10074→10073 字节（差的 1 字节是新值本身短一个字符），79→79 行注释、265→265 行、权限 0644 保留 |

「类型化 Config 相同」正是这个缺陷能长期潜伏的原因：**它对程序行为无害，只对运维知识有害**。而被抹掉的注释里确实有只此一处的知识——`config.yaml:133` 本地地址备选、`:164` CDN 回退语义、`:122-126` 被注释掉的 `ollama:` 段（§22.8 拿它当证据）、`:257-265` 被注释掉的本地数据库段。

必须说明：这个缺陷**在 HEAD 上就已存在**（`git diff` 对该文件为空，不是我引入的）。但批次八/九把 `pkg/conf` 做成唯一读者、又把 `Reload`/`LoadFile` 接到这个端点上，于是它变成了整个配置子系统**唯一**的破坏性写路径——修它是本批的责任。

最终实现只用 `yaml.Node` 取目标节点的行列号，其余全靠原文：保留行首缩进、键名、冒号后的空格，以及值后面的**行内注释与其原始间距**（`432000  # 5 天` 的两个空格原样接回）；CRLF 文件里的 `\r` 也接回。字符串一律双引号输出（转义 `"` `\` `\n` `\t`，其他控制字符拒绝写入），整数裸输出。

**落盘前四道校验**（把候选内容整体重解析后比对，任何一道不成立就返错、不写）：

1. 叶子键数不变（122 → 122）；
2. 每个目标键确实生效（比对**解析回来**的值，不是比对文本）；
3. 所有非目标键的解析值逐键全等；
4. 行数不变。

第 2 道不是形式主义：它挡住了跨行标量。`a: "one\n  two"` 被改成 `a: "x` 之后续行残留，重解析直接报错；即便某种形状能解析成功，解析值也会是 `"x two"` 而不是 `"x"`，同样被拒。

### 24.5 六种敌意形状的实测：全部拒绝，且**零字节落盘**

四道校验是推理出来的，能不能真挡住要实测。造了六种形状逐一喂给 `patchYAMLFile`：

| 形状 | 结果 |
|---|---|
| 双引号跨行标量 | 报错「改值后文档不再合法（已放弃写入）」，文件未变 |
| plain 跨行标量 | 同上，文件未变 |
| 块标量 `|` | 报错「是块/流式标量，无法定点改值」，文件未变 |
| 流式映射 `{x: 1}` | 报错「不是标量，无法定点改值」，文件未变 |
| 别名 `*anc` | 报错「不是标量」，文件未变 |
| 制表符缩进 | 报错（yaml.v3 本身拒绝解析），文件未变 |

六种全部**报错且不落盘**，「宁可失败也不写坏文件」这条性质被证明而不是被声明。探针跑完即删。

另外两件先查证再动手的事：

- **重复键**：`locateYAMLNode` 取**第一个**匹配，而 viper 取**最后一个**。若文件里有重复键，管理台改了第一个、生效的却是第二个 → 看起来成功的静默空操作。实测真实 `config.yaml` **重复键 0 个**，今天不可达；
- **跨行标量**：实测真实 `config.yaml` **跨行/异形标量 0 个**。同时确认 `yaml.Node.LineComment` 含 `#` 且只取行尾那个真注释（`b: "x # y"  # real` → `LineComment == "# real"`），所以 `strings.LastIndex` 定位正确——这也是为什么必须用 `LastIndex` 而不是 `Index`。

### 24.6 #33 40 键迁移的默认值反转审计（结论：无反转）+ #35 死字段

**#33**：批次九把 40 个键从散落的 `viper.New()` 迁到 `pkg/conf`，最大的风险是「缺失时旧代码给 `true`、新代码给 `false`」这类默认值反转。做法是读完整的 `4f51845e..c083ce8a` diff，把每一个被删的读取点与 `derive.go` 里的替代物逐条对齐：

| 键 | 旧默认 | 新实现 | 一致 |
|---|---|---|---|
| `moe.bot_scheduler_enabled` | 未设置 → `true` | `inheritBool(..., true)` | ✓ |
| `moe.dream_scheduler_enabled` | 未设置 → `true` | `inheritBool(..., true)` | ✓ |
| `moe.bot_scheduler_tick_seconds` | ≤0 → 60s | 同 | ✓ |
| `moe.dream_scheduler_tick_seconds` | ≤0 → 300s | 同 | ✓ |
| `llm_inference.context_tokens` | ≤0 → 8192 | `DefaultContextTokens = 8192` | ✓ |
| `moe.bot_smart_*` | `if m > 0` 才覆盖 | `SmartRetry()` 返回原值，`>0` 守卫留在调用方 | ✓ |
| `moe.topic_analyze_model` | → `llm_inference.memory_model` | `firstNonEmpty` 同链 | ✓ |

**运行时实证**：真实启动日志里 `moe bot scheduler started tick=1m0s`、`moe dream scheduler started tick=5m0s`，与 60s/300s 缺省逐字对应（§24.9）。

最尖锐的一处是 `moe.bot_post_model`：迁移前 `runtime/post_model.go` 与 `brain/refine.go` 各有一个同名 `loadBotPostModelFromViper`，**回退链还不一致**（runtime 认 `llm_inference.chat_model`，brain 不认）。收敛成一个 `BotPostModelConfigured()` 之后，`refine.go` 凭空多了一级回退。查证结果：**`chat_model` 在 `config.yaml` 里根本不存在**（下面那份「EXTRA 10 个」清单独立确认），所以 `firstNonEmpty(x, "") ≡ x`，多出来的那一级今天是惰性的。它仍是一个陷阱——一旦有人加上这个键，`brain.resolveRefineModel` 就静默获得一个**优先级高于注入值 `deps.Inference.DefaultModel`** 的文件级回退——已在 `derive.go:102-108` 写明。

**穷尽式标签覆盖检查**（把「我抽查了 11 个键」升级成「没有任何键能再次静默失效而不被发现」）：用反射走完 `Config` 的全部 **97** 个建模字段，与真实文件的 **122** 个叶子键逐一对照：

- 每个建模键都读到正确的值（唯一一处看似不符的 `local_models.catalog` 是探针自己的假阳性——它用 `fmt.Sprintf("%v")` 比 `[]map[string]any` 与 `[]LocalModelEntry`，8 个字段逐个手工核对后完全一致）；
- **35 个文件里有、结构体没建模的键全部有归属**：16 个 `*_api_in_process` 由 `inheritBool` 动态拼键读取（**它们确实被读**，所以不该进死键清单）、13 个 `memory.search.*` / `memory.embedding.*` 与 6 个其他键已记在 `config.go:17-25` 并已在第十批 #26/#27 处置；
- **10 个结构体建了模、文件里没有的键**：其中 5 个是 `ollama.*` 回退（§22.8 已判定可删），另外 5 个见下面的 #35。

**#35**：`MoeProduction` 原有 5 个字段，删掉 4 个。`InternalGRPCPort` / `PilotHTTPPort` / `PilotGRPCPort` 建模的是一个**不存在的拓扑**——单进程 HTTP-only，既无 gRPC 监听者也无 pilot 进程，是第五批移除 `MoePilot` 时的残留，而且这三个键连 `config.yaml` 里都没有；`UnifiedEntry` 在文件里但全仓零读者。四者都已记在变更记录 §18.2 的「50 个死键」里，**代码却仍在建模**，与文档相互矛盾。删掉并把 `unified_entry` 补进 `config.go` 头部的死配置清单，让代码与文档口径一致。

### 24.7 #36 `companion.fakeStore` 数据竞争：`-race` 曾对全仓失效

`go test -race ./...` 在 `internal/biz/companion` 报 3 处 DATA RACE（`TestPushProactiveFailureOnlyReleasesItsOwnReservation`）。溯源：`Engine.pushProactive` 并发调用 `recordCompanionEvent → CreateCompanionEvent`（`engine.go:232`、`:241` → `:1192`），而测试替身 `fakeStore` 没有锁，`CreateCompanionEvent` 裸着 `append` 到 `s.companionEvents`。

**这不是生产竞态**：真实 store 走数据库、每个调用各自事务。但它必须修——它让 `-race` 对**整个仓库**失效，而本批正是用 `-race` 来证明 #31 的修复。工具本身不可信时，用它得出的结论也不可信。

修法：给 `fakeStore` 加 `mu sync.Mutex`，25 个方法全部加锁。加锁本身机械，真正的风险是「方法返回内部数据的指针」——那样解锁之后调用方仍能并发改写，锁就白加了。先查证这一类：`grep 'return &s\.\|return s\.[a-z]*\['` **零命中**，所有返回都是副本（例如 `GetMemoryByID` 是 `row := s.memories[i]; return &row`）；再查证重入：25 个方法体内**没有任何一个调用另一个 `fakeStore` 方法**（非重入锁会自死锁）。两项都清白，所以统一加锁是完备的。`go vet` 的 copylocks 也过——`newFakeStore()` 返回指针，结构体从不按值拷贝。

结果：`go test -race -count=1 ./...` → **33 个包 ok，1 个失败**，且那一个是已知的 `toolaudit` 阈值（`expected >=6 tools, got 5`，§17.6(b)），与本批无关。此前是 32 ok / 2 失败。

### 24.8 差点误判的一处：第 4 类陷阱（误读变更记录自己的口径）

`config-hygiene-review:1350` 写着某键「✅ 已删」，而 `pkg/conf/config.go` 的 `MoeProduction` 结构体当时仍在建模这些键——看起来是一处文档与代码的矛盾，差点当成第十批的漏网之鱼去「修文档」。

（这里刻意**不写行号**：#35 删掉那四个字段之后行号已经移动，写上去就是 §23.8 警告的那类悬空引用。）

读上下文才发现：那一行的表头是「死键类别 / 键数 / 状态」，整张表服务于「分母 105 的来历」。在**它自己的口径里**，「已删」指的是这个键的**引用**随 `moeconf` 整包一起删掉了（口径 F 数的是引用），不是指结构体字段或 YAML 行也删了。原文准确，不需要改。

这是继第十批 §23.3 那三类之后的**第 4 类陷阱：误读一份变更记录自己的口径**。判据：看到「文档 vs 代码」矛盾时，先确认两者是否在数同一件事——本例里一个数引用、一个数字段，分母都不同。真正的矛盾（#35 那四个字段）是**同一口径下**的不一致：§18.2 把它们归入死键，代码却仍在建模。

### 24.9 真实启动 + 活进程端到端验证

按「确保每一次的调整完 程序都是正确可运行」这条标准，本批不止跑单测，而是启了一个真进程，并且**故意用自定义 `-f`**，好让 `-f` 权威性和写回路径在活进程上一起被验证：

1. `cp config/config.yaml /tmp/dashf/custom.yaml`，只把 `runtime.http_port` 改成 `18899`（真配置是 8888，`./config/config.yaml` 从 backend/ 启动时**可达**——所以这是一个真判别器，不是摆设）；
2. 在 `backend/` 目录里启动 `-f /tmp/dashf/custom.yaml`；
3. 日志 `moe-social ready: Kratos HTTP-only on port 18899`，`lsof` 确认监听在 `*:18899` → **`-f` 权威，没有被 `./config` 盖掉**；
4. `tick=1m0s` / `tick=5m0s` → #33 的默认值在运行时实证；
5. `POST /api/admin/login`（`admin`/`admin123`，来自 `admin.bootstrap`）拿 token；<br>↪️ 这一步是当时的真实记录，**今天仍然成立**，但账号的**来源**在第十二批之后变了：新部署的超管由 `RunAutoMigrate` 读 `admin.bootstrap.password` 创建（§25.3），那个免鉴权的 `POST /api/admin/bootstrap/account` 已删除。测试库里这一行是历史遗留，所以登录照旧可用；`config.yaml:28` 的 `admin123` 也仍在，正式版随凭据轮换一起换掉；
6. `GET /api/admin/runtime-config` → `config_file` 返回 **`/tmp/dashf/custom.yaml`**；
7. `PUT` 两处改动（`image.max_bytes` + `image.local_dir`）→ 对 `-f` 文件 `diff` 出**恰好 2 行**；对被跟踪的 `backend/config/config.yaml` 做 `md5` 比对 → **不变**；`git diff --stat -- config/config.yaml` → **空**；
8. 保留性核验：注释 **79 → 79** 行、总行数 **265 → 265**、字节 10074 → 10073（差的 1 字节是新值本身短一个字符）、权限 `-rw-r--r--` 保留（这个文件含数据库口令与第三方密钥，不能顺手放宽）；
9. 二次 GET 反映新值 → `conf.LoadFile` 确实把进程内缓存指向了刚写的文件；进程仍 ALIVE，响应 1ms；
10. 停进程，查 `life_items`：**594 → 600**，正好一次启动的 6 行（§22.7 / §0 第 17 行的非幂等 seed 仍在，未处置）。

### 24.10 刻意保留的行为变化与已知良性项（登记，不修）

- **行为变化**：目标叶子键在文件里**不存在**时，`patchYAMLFile` 现在**报错**（错误信息给出完整点路径并提示「请先手工加上这一行再用管理台改它」），而 `viper.Set` + `WriteConfig` 会凭空创建它。理由：按行追加需要猜父块的缩进与结束位置，风险高于让运维手工加一行。5 个可改键在**被跟踪的** `config.yaml` 里都存在（`:34`、`:132`、`:154`、`:155`、`:156`）；**VPS 上那份已永久分叉的副本未核验**（§0 第 9 行）。
- **良性**：两个管理员并发保存没有文件锁，可能丢一次更新。旧实现（每请求新开一个 viper）暴露面相同，非本批引入。
- **良性**：`derive.go` 里的函数会多次调用 `Get()`（例如 `GameInference()` 先 `Inference()` 再 `Get().LLMInference`），两次调用之间若正好有一次 `LoadFile` 换入，就会跨快照取值。两个快照各自都是自洽的 `Config`，函数逻辑也不要求它们同源，实际影响为零；彻底消除需要把 `derive.go` 全部改成「取一次快照再派生」，属过度设计，不动。
- **已核验**：全仓 `conf.Get()` 的 34 处调用点（`pkg/conf` 外、非测试）**无一处修改返回的 `*Config`**——要么读标量，要么 `img := conf.Get().Image` 按值拷贝结构体。所以「旧指针从不被就地改写」这条 #31 依赖的不变式成立。
- **已核验**：`autoFailed == true ⟹ current == nil` 这条不变式成立——`autoFailed` 只在 `Get()` 里 `loadLocked()` 失败时置位（此时 `current` 必为 nil），而 `LoadFile`/`Load` 成功都会把它清回 false。
- **已核验**：全仓再无 `viper.WriteConfig()` / `SafeWriteConfig()` 调用点（只剩注释与测试里的历史指涉），破坏性写路径已彻底消除。

### 24.11 口径 F 与验证汇总

口径 F **未回退**：仍是 8 处 / 7 个唯一键 / 3 个文件 / **0 个读取行**。其中 5 处写回键字面量从 `v.Set("image.max_bytes", …)` 变成了 `yamlEdit{"image.max_bytes", …}`——**数量、文件、语义角色（写回而非读取）都不变**。3 处 `conf.IsSet(` 实参在 `oauth_wechat.go:24,66` 与 `config_override.go:93`，原样保留（`IsSet` 的「未设置即继承」语义结构体表达不了，见 `load.go:18-22`）。

| 项 | 结果 |
|---|---|
| 改动文件 | 5 改 + 1 新增（`utils/admin_runtime_config_test.go`，~330 行）；**未提交**，叠在用户自己创建的 `c083ce8a` 之上 |
| `go build ./...` | rc=0 / 0 行 |
| `go vet ./...` | rc=0 / 0 行 |
| `gofmt -l`（本批改动文件） | 空。（`utils/http_client.go`、`utils/retry.go`、`utils/user_behavior.go` 仍在 §17.6(a) 那份 127/928 的存量清单上，非本批引入，未动） |
| `go test -race -count=1 ./...` | **33 个包 ok，1 个失败** = 已知的 `toolaudit` 阈值（此前 32 ok / 2 失败，DATA RACE 已消除） |
| `go test -race ./pkg/conf/` | ok（含新增的 `TestReloadNeverExposesUnloadedWindow`） |
| `go test -race ./utils/` | ok（含新增的 3 个测试、8 个子测试） |
| 真实启动 | 成功，`-f` 权威性 + 迁移后默认值均在活进程上实证（§24.9） |
| 被跟踪的 `config/config.yaml` | `git diff --stat` 为空，**逐字节未变** |
| 测试库副作用 | `life_items` 594 → 600（一次启动的已知非幂等 seed；第十二批已修：600 → 6 并建唯一索引，见 §22.7 ↪️） |

**判别力声明**（每条新测试都靠「临时改坏实现看它是否失败」验证过，不是写完就算）：

- `TestReloadNeverExposesUnloadedWindow`：把 `Reload` 改回旧写法 → 失败（459501 次错值）；
- `TestPatchYAMLFilePreservesComments`：把 `patchYAMLFile` 换回 `viper.Set` + `WriteConfig` → 失败（注释 79→0）；换成 `yaml.Marshal(&node)` → **也失败**（行数 265→241）；
- `TestResolveUnifiedConfigPathHonorsDashF`：把 `conf.Path()` 那一顺位去掉 → 失败，且断言消息会点名它错选了哪个哨兵文件；
- `TestPatchYAMLFileMissingKey`：其中一个子测试曾经**真抓到一个缺陷**——`locateYAMLNode` 的错误信息只报最后一段（「不存在键 max_bytes」），因为 `full` 是在递归里用剩余路径重新拼的。修法是让调用方把完整点路径一路传下去。这条不是我推理出来的，是测试逼出来的。

---

## §25 2026-09-16 第十二批：一个免鉴权的超管创建端点 + 一个让全仓测试静默失效的门禁

本批起点是 §11 P0-3「`admin_seed.go` 里有 `admin123` 代码级兜底」。按老规矩从**攻击者能看到的出口**往回追，而不是停在被报告的症状上——结果发现兜底只是这条链上最不要紧的一环，真正的洞是一个任何人都能调的 HTTP 端点；而在给修复写变异测试的过程中，又撞上了本仓迄今最严重的一次假干净：**全仓所有依赖数据库的测试用例一直在静默跳过，`go test ./...` 报 ok 什么都没证明**。

### 25.1 结论

| 项 | 结论 |
|---|---|
| P0-3 的真实严重度 | 不是「弱口令兜底」，是**未授权提权**：空库部署上任何人 POST 一次即可造出 `super_admin` 并拿到全权 token |
| 处置 | 需求方选定「迁移时种账号 + 删端点」：RPC、两个 message、免鉴权白名单条目、service/biz/utils 三层实现、legacy 死类型**全部删除**；种账号改由 `RunAutoMigrate` 在末尾执行 |
| 只删兜底够不够 | **不够，且属于安全表演**——被跟踪的 `config/config.yaml:28` 显式写着 `password: "admin123"`，代码里不兜底，端点照样能造出弱口令超管 |
| 门禁假干净 | `go env CGO_ENABLED` 本机持久为 **0** → gorm 的 sqlite 驱动不可用 → 各处 helper `t.Skip` / 整文件 `//go:build cgo` 排除 → `go test ./...` **报 ok** |
| 被藏住的失败用例 | **3 条**，全部为长期潜伏，与本批改动无关（已在 HEAD `0459e256` 上逐条复现） |
| 机制 | 新增 `utils/cgo_canary_test.go`（`//go:build !cgo` 哨兵）+ Makefile `test` / `test-race` 强制 `CGO_ENABLED=1` + `check` 改为跑全仓 |
| 收口状态 | `make check` rc=0（**34 包全 ok，0 FAIL**）· `make test-race` rc=0（无 DATA RACE）· `go build` / `go vet` rc=0 · gofmt clean |

### 25.2 证据链：这个洞为什么是真的

从出口往回追，六环缺一不可，每一环都实测过：

| # | 环节 | 位置 | 为什么致命 |
|---|------|------|-----------|
| 1 | `POST /api/admin/bootstrap/account` 在**免鉴权白名单**里 | `internal/server/auth.go`，与 `/api/admin/login` 并列 | 不带任何 token 即可抵达 handler |
| 2 | `AdminBootstrapAccountReq` 是**空消息** `{}` | `api/admin/v1/admin_messages.proto` | 结构上就不存在任何能携带校验凭据的字段——想加校验都没地方加 |
| 3 | biz 层写着 `_ = ctx; _ = in` | `internal/biz/admin/auth.go`（旧 `:57-66`） | 显式声明「入参我不看」，即「没有校验」这件事是写在代码里的 |
| 4 | `utils.BootstrapAdminAccount` 回落到 `admin123` | `utils/admin_seed.go`（旧 `:33-34`） | 造出来的超管口令众所周知 |
| 5 | `Count` **不含 `Unscoped`** | 同上 | `AdminAccount` 有 `gorm.DeletedAt` 软删除——把管理员全部软删，表就「看起来空了」，洞**可以重新打开**；而 `Username` 上有 `uniqueIndex`，软删行仍占索引，再 `Create` 必撞唯一键 |
| 6 | `RunAutoMigrate` 从不种账号 | `utils/db_migrate.go` | 于是这个端点是**首次超管的唯一入口**，`admin_seed.go` 自己那句注释「首次迁移时创建默认超管」是**假的** |

第 6 环是闭合点：正因为迁移不种账号，这个端点才不能被简单删掉了事——删了它，新部署永远登不进管理后台。所以处置必须是「换一个入口」而不是「关掉入口」。

**它不是理论风险，是被写进运维手册的正式流程**：`docs/dev/moe-admin.md:61` 把 `POST /api/admin/bootstrap/account（无需 Token，表为空时）` 列为「首次超管」的官方做法，`backend/openapi.yaml` 也导出了它。同时在 `moe-admin/` 与 `lib/` 里**零调用方**——手册教人手工 curl 一个免鉴权提权接口。

### 25.3 处置：迁移时种账号 + 删端点

proto 与生成物（用 `make api-one PROTO=api/admin/v1/admin_messages.proto` 单模块重生，避免把本机 protoc 版本戳进所有域）：

| 文件 | 变化 |
|------|------|
| `api/admin/v1/admin_messages.proto` | 删 `rpc AdminBootstrapAccount` + `AdminBootstrapAccountReq` + `AdminBootstrapAccountResp`；`AdminBootstrapAchievementsReq` **保留**（那个端点需要 admin token） |
| `admin_messages.pb.go` | 2480 行 diff —— 删一个 message 会让后续所有 `msgTypes[N]` 索引重排，**这个量级是正常的**，不是改坏了 |
| `admin_messages_grpc.pb.go` / `_http.pb.go` | 42 / 41 行 |
| `openapi.yaml` | 39 行，路径数 → **291** |
| `internal/server/routestats/proto_routes_gen.go:5` | `protoHTTPRouteCount` **320 → 319** |

Go 层：

| 文件 | 变化 |
|------|------|
| `internal/server/auth.go:68` | 白名单只剩 `/api/admin/login` |
| `internal/server/protohttp/adminapp/adminapp.go` | 删 `(*Server).AdminBootstrapAccount` |
| `internal/service/admin/admin_login.go` | 删 `(*AppService).AdminBootstrapAccount`，文件只剩 `AdminLogin` |
| `internal/biz/admin/auth.go` | 删 `BootstrapAdminAccount`（11 行纯删除）；`utils.GenerateAdminToken` 与 `gorm.ErrInvalidDB` 仍被 `AdminLogin` 用着，两个 import 都保留 |
| `utils/bootstrap.go` | 删 `BootstrapAdminAccount(db) int32`——它用 `err != nil \|\| count > 0` 吞掉了 Count 的错误，使「表不存在」与「已种过」不可区分 |
| `utils/admin_seed.go` | **重写**：返回 `error`；无 `admin123` 兜底，缺口令即返回 `ErrAdminBootstrapPasswordUnset`（`:16`）且不写库；`Count` 加 `Unscoped()`（`:34`） |
| `utils/db_migrate.go:98-108` | `RunAutoMigrate` 末尾种账号，用 `migrateEntriesInclude(entries, "admin_accounts")` 守卫 |
| `internal/legacy/types/types.go` | 删死类型 `AdminBootstrapAccountData` / `AdminBootstrapAccountResp`（全仓 grep 只有自引用） |
| `docs/dev/moe-admin.md` | 重写「首次超管」那一行 + 加「不要再把这个端点加回来」的告警块，把上面六环写进去 |

**两处刻意的取舍**：

1. **`admin.bootstrap.password` 未配置时是响亮跳过，不是硬失败。** `db_migrate.go:101` 打印 `[admin] !! 未创建默认超管：…请在 config.yaml 设置 admin.bootstrap.password 后重跑迁移，否则管理后台无法登录` 然后**继续**。理由：一个配置层面的技术性缺失不应该让整个服务起不来（需求方的底线是「每一次调整完程序都是正确可运行」）。但也不是静默——日志里带 `!!` 和补救步骤。
2. **种账号必须被迁移范围守卫。** `RunAutoMigrate` 支持 `MigrateOptions.Models` 按 registry key 局部迁移；`Models: ["users"]` 时 `admin_accounts` 表根本没建，此时去 `Count` 会报 `no such table`，而那不是 `ErrAdminBootstrapPasswordUnset`，会让**整次迁移失败**。守卫不是防御性冗余，是必需项——变异 4 实测证明了这点（§25.6）。

### 25.4 门禁级假干净：`CGO_ENABLED=0` 让全仓 DB 用例静默跳过

本批最重要的产出不是那个安全修复，是这条。

**发现过程**：给新的种账号测试做变异验证时，变异 1（把 `admin123` 兜底加回去）**返回了 `ok backend/utils`**。按既定纪律，「该失败的没失败」必须先怀疑验证命令本身而不是接受结果——加 `-v` 重跑，看到全部 sqlite 用例都是 `--- SKIP`，包括仓里原有的 `TestRunAutoMigrateSkipsUnchanged`。

**根因**：`go env CGO_ENABLED` 在本机被持久写成 **0**。三处机制各自把这件事变成静默：

| 位置 | 机制 |
|------|------|
| `utils/db_migrate_test.go:88-100` `testMigrateDB` | `gorm.Open(sqlite…)` 报错且错误串含 `CGO_ENABLED` → `t.Skip` |
| `internal/biz/admin/topic_tags_write_test.go:19` `openTestDB` | 同上，`t.Skip("sqlite in-memory test requires CGO")` |
| `pkg/achievement/activity_test.go:1` | `//go:build cgo` —— **整个文件不参与编译**，连 SKIP 都看不到 |

而 `/usr/bin/clang` 是**在的**，`CGO_ENABLED=1` 完全能跑。也就是说这不是环境缺能力，是环境配置把能力关掉了，而测试选择了对此沉默。

**量化证据**（在 HEAD `0459e256` 上、不含本批任何改动跑出来的）：

```
CGO_ENABLED=0 go test ./internal/biz/admin/ ./pkg/achievement/  → ok / ok     （7 个 --- SKIP）
CGO_ENABLED=1 go test ./internal/biz/admin/ ./pkg/achievement/  → FAIL / FAIL （0 个 SKIP）
```

放到全仓范围，这个差值更能说明问题：

```
CGO_ENABLED=0 go test -v ./...  → 19 个 --- SKIP
CGO_ENABLED=1 go test -v ./...  →  1 个 --- SKIP
```

**剩下的那 1 个是正当的**：`TestSendFeishuTestCardIntegration`（`feishu_test.go:55`）由 `FEISHU_INTEGRATION_TEST=1` 显式选择，要连真实飞书 IM 接口。它跳过是因为「没有授权去打外部服务」，而不是因为「环境缺一件本该有的能力却没人说」——这两者的区别正是本节要划的那条线。18 个静默跳过归零，1 个有据跳过保留。

**为什么能烂这么久**——三层门禁同时失效，任何一层生效都会立刻暴露：

| 层 | 状态 |
|---|------|
| `make check`（旧） | 只跑 `./internal/platform/moesocial/... ./internal/server/routestats/...` **两个包**，出事的三个包一个都不在里面 |
| CI | `.github/workflows/` 里**没有任何 `go test`**；唯一提到 CGO 的是 `n100-deploy.yml:37` 的 `CGO_ENABLED=0 go build` |
| 本地 `go test ./...` | 被 §25.4 的静默跳过吃掉了 |

这与 §23.8（缺「文档引用的文件/行是否还存在」的断言）、以及「正对照钉在 HEAD 上、修合一提交就腐烂」是**同一类缺陷**：不是某次判断错了，是**没有任何机制会在它错的时候发出声音**。所以本批的处置重心放在机制上，不是放在「下次记得加 CGO_ENABLED=1」。

**加的机制**：

| 文件 | 作用 |
|------|------|
| `utils/cgo_canary_test.go`（新） | `//go:build !cgo` 哨兵，只在 CGO 关闭时编译进来，直接 `t.Fatal` 并给出正确命令。实测：`CGO_ENABLED=0 go test -run TestDBTestsRequireCGO ./utils/` → FAIL + 完整提示语 |
| `Makefile:54-58` | 新增 `test` / `test-race`，两者都写死 `CGO_ENABLED=1` |
| `Makefile:61-63` | `check` 由「编译 + 测 2 个包」改为「编译 + `$(MAKE) test`（全仓）」 |
| `Makefile:4` | `test` / `test-race` 登记进 `.PHONY` |
| `AGENTS.md:16,29-38` | 命令表里的裸 `go test ./...` 换成 `make test` / `make test-race`；覆盖率命令补 `CGO_ENABLED=1` 前缀并注明「cover.out 照样生成、只是这些路径全被算成未覆盖且无报错」 |
| `.cursor/rules/moe-social-engineering.mdc:137-149,343-345` | §7.1 质量门禁同步改写并加 ⚠️ 块；命令速查表里 `make check` 的说明「核心包单测」已失真（现在是全仓），一并修正 |

最后两行不是顺手改文档：**规则 SSOT 与 AGENTS.md 里那三处命令，本身就是假干净的再生产装置**。哨兵能让人在跑错命令时看到失败，但如果规则文件继续把错命令写成标准做法，每个人都会先撞一次哨兵再去查为什么。机制要闭合，就得连「文档教人跑哪条命令」一起改。

`t.Skip` **保留**：没有 C 工具链的机器确实跑不了 sqlite，让它硬失败是错的。错的是「没人知道自己跳过了」，哨兵解决的正是这一件事——它把静默通过换成一条自解释的响亮失败，而且**绑在编译标签上，不会随用例数量增减而腐烂**。

### 25.5 被它藏住的 3 条失败用例

三条全部在 HEAD 上复现过，与本批改动无关（`git diff --stat` 显示 `pkg/achievement` **零改动**，`internal/biz/admin` 只有 11 行纯删除）。

**(a) `TestDeduplicateGiftsByName` —— 出生即不可能通过**

```
topic_tags_write_test.go:54: UNIQUE constraint failed: gifts.name
```

`git log -S'uniqueIndex' -- backend/model/gift.go` → 唯一命中 **`8c701f61 feat(api): 新增话题标签与礼物去重功能`**。同一个提交干了三件事：加 `DeduplicateGiftsByName`、给 `model/gift.go:10` 的 `Name` 加 `uniqueIndex`、加这个会插入两条同名礼物的测试。**索引与夹具从第一天起就互相矛盾**，第二条 `Create` 必然被拒，用例根本走不到被测函数。它从未执行过一次，所以从未有人发现。

被测函数**不是死代码**——`internal/service/admin/admin_gift.go:76` 是真调用方。它的服务对象是「索引上线之前就已经有重复行的老库」（例如那台远程测试 MySQL），全新库上它天然无事可做。所以修法不是删测试，是**让夹具还原它真正针对的那个前提**：插入前先 `db.Migrator().DropIndex(&model.Gift{}, "Name")`。用 Migrator 按字段名丢，避免把 GORM 生成的 `idx_gifts_name` 写死。

**(b) `TestBumpDailyActivityRevivesSoftDeletedRow` —— 夹具两处，第二处是「约定用了一半」**

第一处显而易见：`no such table: user_weekly_activity`。`bumpDailyActivity` 在 `activity.go:184` 会调 `syncWeeklyActivity` 写周表，夹具只 `AutoMigrate` 了日表。

补上表之后**仍然失败**，才露出第二处：

```
activity_test.go:52: load row: record not found
```

production 写入的是 `activityStorageDate(day)`（**UTC 零点**，`activity.go:115` 的 `dates[0]`，函数注释写明「避免写入 MySQL 时因会话时区变成前一天」），而夹具直接写了 `todayDate(time.Now())`（**上海零点，带 `+08:00` 偏移**）。于是 `findDailyActivity` 的 `DATE(activity_date) = ?` 和用例自己末尾那句断言查询都匹配不到这行。

值得记下来的是：**同一个测试文件里，写入用了一个约定，断言查询用了另一个约定**（第 49 行已经在用 `activityStorageDate(date)`）。作者知道这个约定，只应用了一半。这类缺陷在只会读一遍的评审里几乎必然漏掉——只有真跑起来才会撞到。

**(c) `TestBuildSchemaItemsCoversAllTools` —— 写死的数量阈值必然腐烂**

```
record_test.go:12: expected >=6 tools, got 5
```

注册表 `pkg/moe/tools/registry.go` 现在正好 5 个：`post_search` / `post_get` / `post_create` / `brain_refine_episode` / `brain_curate_memories`。而旧测试**自己的注释**（`:19`）点名的是 `memory_search`——这个工具早就不在注册表里了。阈值写死的那天就注定会随注册表增减而失效。

旧用例还有两处**看起来在断言、实际什么都没断言**：

```go
if len(it.AllowedTiers) == 0 && it.Name != "" {
    // s0 allows nothing — memory_search should still have tiers   ← 空 if 体
}
_ = core.TierS2.AllowsTool("post_create")                          ← 丢弃返回值
```

重写为三条真断言：① `len(items) == len(tools.OpenAISchemaList())`——从注册表推导，**不再有魔法数字可腐烂**；② 逐工具逐档位比对 `AllowedTiers` 与 `AllowsTool` 必须一致，且 `s0` 不得出现在任何工具的档位里（`AllowedTiers` 是给管理台看的展示层，`AllowsTool` 是真正放行的执行层，两者不同源就等于管理台在说谎）；③ `post_create` 在 s0/s1 必须被拒、s2/s3 必须放行——这条是**策略断言**，改档位策略时必须同时改它，是有意的。

### 25.6 判别力声明（每条都靠临时改坏实现验证，不是写完就算）

种账号与鉴权，5 条变异全部正确变红：

| # | 变异 | 结果 |
|---|------|------|
| 1 | `admin_seed.go` 加回 `admin123` 兜底 | FAIL `TestSeedAdminAccountRefusesWithoutPassword`：`err = <nil>, want ErrAdminBootstrapPasswordUnset` |
| 2 | 去掉 `Count` 的 `Unscoped()` | FAIL `TestSeedAdminAccountDoesNotResurrectAfterSoftDelete` |
| 3 | 删掉 `RunAutoMigrate` 末尾的 `SeedAdminAccount` 调用 | FAIL `TestRunAutoMigrateSeedsAdminOnFullMigration`：`全量迁移后应存在 super_admin: record not found`。**其余 3 条种账号用例仍然全 PASS** —— 这正是它存在的理由：没有这条，前 3 条只证明 helper 本身正确，证不出**有人调它**；端点删掉之后迁移是首次超管的唯一入口，接线断了等于新部署永远登不进后台 |
| 4 | 去掉 `migrateEntriesInclude(…, "admin_accounts")` 守卫 | FAIL `TestRunAutoMigrateSkipsSeedingWhenAdminAccountsOutOfScope`：`按 users 局部迁移失败: seed admin account: count admin accounts: no such table: admin_accounts` |
| 5 | `auth.go` 加回 `\|\| path == "/api/admin/bootstrap/account"` | FAIL `TestJWTAuthFilterAdminPaths//api/admin/bootstrap/account`：`在没有 admin token 的情况下到达了 handler` |

变异 3 的那句「其余 3 条仍然 PASS」是这批里最有价值的一个观测：**它直接量化了「helper 正确」与「helper 被接线」是两件事**。

toolaudit 重写，2 条变异正确变红：

| # | 变异 | 结果 |
|---|------|------|
| A | `BuildSchemaItems` 丢掉注册表首项 | FAIL：`工具数与注册表不一致：BuildSchemaItems 返回 4 项，注册表有 5 项` |
| B | `AllowedTiers` 不再由 `AllowsTool` 推导，写死四档 | FAIL，一次报出 6+ 条：`post_get 的 AllowedTiers 含 s0`、`post_create 在 s1 档不一致：AllowedTiers=true，AllowsTool=false` …… |

(a)(b) 两条夹具修复的判别力由**修复前后的实际序列**给出：改之前分别报 `UNIQUE constraint failed` / `no such table` / `record not found`，改之后 PASS，中间没有别的改动。

### 25.7 登记不修的已知项

| 项 | 位置 | 处置与理由 |
|---|------|-----------|
| 已删端点仍留在代码图快照里 | `moe-admin/public/dev/codegraph/backend.json:1055-1062, 6686-6694` | 入库的**快照产物，仓内没有生成器**。不手改 6000+ 行 JSON——手改一个无法重生的产物只会让下次重生时更难对账。登记为已知陈旧 |
| 工具生成的 wiki 仍引用旧函数 | `.qoder/repowiki/…/管理端业务层（Admin Biz）/架构设计.md:5` 提到 `BootstrapAdminAccount` | 同上，工具产物，不手改 |
| **中文乱码（GBK 误编码）** | `deploy/config/config.go:53,56,100`（`"璇诲彇 config.local.yaml: %w"` 应为「读取」）· `internal/server/protohttp/adminapp/adminapp.go:13,23`（`// Server 闂佽楠哄﹢閬嶅磻…`） | **是一类缺陷，不是两处笔误**：某次编辑用错了编码。其中 `config.go:100` 那条在**错误信息字符串**里，会直接展示给运维。~~本批未动（不在范围内），但值得单独开一批扫全仓~~ → **✅ 已在第十六批（§29.2）扫全仓并全部修完**。本行登记的 5 处只是**运维/源码可见**的那一类；全仓扫描实测 **9 处 / 4 文件**，另有**两处终端用户可见**的本行完全没提到：`companion_api.go:374,378,385`（Kratos HTTP 错误的 `message`，直接进 App 弹窗）与 `lib/pages/checkin/checkin_page.dart:826`（签到页进度文案）。影响面比本行记载的严重 |
| `AllowsTool` 仍放行三个已不存在的工具 | `pkg/moe/core/tier.go:39,43` 的 `memory_search` / `memory_get` / `memory_save` | 放行一个不存在的工具本身无害，属死条目。~~**没删**：`AllowsTool` 可能被喂进历史审计记录里的旧工具名，我没有追完全部调用方，不拿猜测当结论~~ → **✅ 已在第十六批（§29.4）追完并摘除**：调用方恰好 2 个（`tools/executor.go:33`、`toolaudit/record.go:90`），两处的名字都来自 5 项注册表；`flow_run.go` 只可能把 `post_create` 交给 `Execute`，历史审计行进不来。唯一可观测差异是一条**本就在失败**的路径上的文案。`tier.go` 行号已变为 `:38-51` |
| `scripts/archive/rpc-defs/common.proto:1117,1119` 仍有 `AdminBootstrapAccountReq/Resp` | 归档目录 | `scripts/gen/` 与 `Makefile` **零引用**，实测确认是死档。归档就该保持归档时的样子，不动 |

### 25.8 §12.6 拆文件已被取消

需求方 2026-09-16 明确否决了「按环境拆分 config」，原话与理由已写进 §12.6 的 ⛔ 块，**取代**了 09-08 那条「暂缓」。一句话摘要：多机器开发、需要来回切换，环境分层会把「改文件」变成「改环境变量再重启」，对他更麻烦。连带 §11 批次 2 / 任务 #17「`config.yaml` 去跟踪」一并挂起（前提是先有 `secrets.yaml` 可拆）。

**不要再把环境分层当待办重新提出。** 本批动 config 的地方只有 `admin.bootstrap.password` 的语义（去掉代码兜底），与拆不拆文件无关。

### 25.9 验证汇总

| 项 | 结果 |
|---|------|
| `make check`（编译 + 全仓 `CGO_ENABLED=1 go test`） | **rc=0，34 包全 ok，0 FAIL** —— 这是全仓测试**第一次真正跑起来还是绿的** |
| `make test-race` | rc=0，34 ok，无 `DATA RACE` |
| `go build ./...` / `go vet ./...` | rc=0 / rc=0 |
| `gofmt -l`（本批触碰的全部文件） | 空。（`gofmt -l ./...` 仍列出 §17.6(a) 那批历史未格式化文件，**无一属于本批**） |
| 哨兵 | `CGO_ENABLED=0` → `--- FAIL: TestDBTestsRequireCGO` + 完整提示语 |
| 已删端点残留 | `bootstrap/account` / `AdminBootstrapAccount` / `BootstrapAdminAccount` 在 `*.go` `*.proto` `*.yaml` `*.ts(x)` `*.dart` 中的命中，**只剩本批自己写的守卫注释与测试用例名**，外加 §25.7 登记的归档目录 |
| `openapi.yaml` | 291 条路径，`bootstrap/account` 残留 **0** |
| 路由计数 | `protoHTTPRouteCount` = **319** |
| 被跟踪的 `config/config.yaml` | 逐字节未变（本批只改**读取语义**，没改文件） |

**本批对方法论的追加**：`t.Skip` 与 `//go:build` 排除是两种**比空输出更危险**的假干净——空输出至少看着可疑，而 `ok backend/utils` 是一个**正面的、可信的、错误的**信号。凡是「环境不满足就跳过」的 helper，都必须配一个「环境不满足就响亮失败」的哨兵，否则它保护的从来不是测试，是绿灯。

### 25.10 真机启动验证（端到端，两轮）

单测与静态检查都过了，但「删掉一个 RPC」这类改动只有把进程真拉起来打一遍才算闭合。做法：复制 `config/config.yaml` 到 `/tmp` 只改端口（**不动被跟踪的那份**），`go build` 出二进制后 `-f` 指向副本启动，不带 `-migrate`。

| 探测 | 结果 | 说明 |
|---|---|---|
| 启动 | `moe-social ready: Kratos HTTP-only on port 18903` | 删 RPC 后进程正常起来，端口只由 `runtime.http_port` 决定 |
| `POST /api/admin/login`（admin/admin123） | **200**，`data.token` 长度 199，`role=super_admin`，`admin_id=1` | 管理后台登录链路完好。响应体是**包了一层**的（`{"code":200,"data":{...}}`），token 在 `data.token`，第一轮按顶层 `token` 解析得到长度 0，是**我读错了包结构**，不是接口坏了 |
| `GET /api/admin/accounts`（带 token） | **200** | **正对照**：证明「什么都 404」不会伪装成「删除成功」 |
| `GET /api/admin/runtime-config`（带 token） | **200** | 第二个正对照 |
| `POST /api/admin/bootstrap/account`（**带 token**） | **404 `404 page not found`** | **决定性一条**：路由确实已注销 |
| `POST /api/admin/bootstrap/account`（无 token） | **401** | auth 过滤器在 mux 之前跑，所以这一条**只证明鉴权层在挡，不证明路由不存在** |
| `GET /api/admin/accounts`（无 token） | **401** | 同上，白名单收窄后其余 admin 路径一律要求登录 |
| 种账号日志 | **无** | 不带 `-migrate` 的普通启动不种账号，符合 `main.go:20` 的 `migrate` 默认 false |
| 进程 / panic·fatal | ALIVE / **0** | 无崩溃、无致命日志 |

**为什么必须打第二轮**：第一轮拿到的是 `401`，当时差点就此收尾。但 401 是 `internal/server/auth.go` 的过滤器发的，它在路由匹配**之前**执行——一个根本没注册的路径，只要前缀是 `/api/admin/` 且不在白名单里，同样会得到 401。也就是说第一轮的结果对「端点是否真的删掉」是**无信息量**的。带上有效 token 让请求穿过鉴权层，才能把两种情况分开：404 = 路由不存在，2xx = 端点还活着。实测 404，且两个正对照都是 200，结论成立。

**如实登记的两条限制**：

| 限制 | 影响与补偿 |
|---|---|
| **没有**对远端测试库跑 `make db-migrate` | 那台 `47.106.175.49` 是**共享的测试库**，跑迁移会真的改表结构，不该拿验证当借口去动它。种账号路径改由 sqlite 单测（`utils/admin_seed_test.go` 5 例）+ 变异 3/4（切断 `RunAutoMigrate → SeedAdminAccount` 的接线）覆盖。**代价**：迁移在真实 MySQL 上的行为本批未经真机验证 |
| 登录探测会往测试库写 `last_login_at` | `admin` 账号的最后登录时间被这次验证刷新了。无法避免——不登录就拿不到 token，拿不到 token 就分不出 404 和 401。写的是测试库、写的是时间戳字段，判定为可接受 |

验证脚本与产物（`/tmp/moe_e2e*.sh`、`/tmp/moe-e2e*/`）已在收尾时删除，未落进仓库。

---

## §26 2026-09-17 第十三批：活 bug 收口 —— 一个免鉴权的写接口群 + 三个永远 400 的 GET 路由

需求方定的顺序是「先修活 bug，再推配置项」，本批就是这个「先」。前四项（#39 反射 panic、#40 缺适配方法、#41 鉴权洞、#48 GET 解码器）已随 `54c5aa45` 与本批工作区改动落地；过程中另外挖出两项**登记不修**的安全缺陷（#47 免鉴权改密码、#50 OAuth 开放重定向）和一项**门禁缺陷**（#49 挂钟依赖用例）。

### 26.1 结论

| 编号 | 缺陷 | 线上表现 | 处置 |
|---|---|---|---|
| #39 | `httpFromContext` 反射读非导出字段 | 三个 raw 透传端点**必然 panic**，全废 | 已修（`54c5aa45`）：迁到 Kratos 原生路由，直接拿 `ResponseWriter` |
| #40 | Companion 三个 RPC + `ListLlmModels` 没写 HTTP 适配方法 | 生产**永远 501**，且不报错、不 404 | 已修（`54c5aa45`）：补齐适配 + 新增 `prototest.AssertRPCsAdapted` 反射审计 |
| #41 | `publicPaths` 白名单不分 HTTP 方法 | 前缀命中的**写路由一律免鉴权** | 已修：拆成读/写两张表，删 10 条死条目，补 1 条飞书回调 |
| #48 | 三个 GET 路由用 `ctx.Bind`（body 解码器） | 浏览器重定向过来的 GET 没有 `Content-Type` → **400 CODEC**，回调逻辑一行都执行不到 | 已修：直接读查询串；`transport/bind.go` 随之删除 |
| #49 | 用例依赖 `time.Now().UTC()` 的小时数 | `make check` **每天 9 小时必红**，门禁不是确定性的 | 已修：钉死免打扰窗口；顺带补上被它掩盖的零覆盖 |
| #47 | `POST /api/user/reset-password` 免鉴权且不校验验证码 | 知道邮箱即可改任意账号密码（**账号接管**） | **登记不修**：需求方 2026-09-17 明确「这个暂时不做处理」 |
| #50 | OAuth `state` 被当回跳地址，只校验 scheme 不校验 host | 302 到任意外部站点**并把授权码带过去** | **登记不修**：修法需要先定 host 白名单策略，与多机器开发冲突 |

### 26.2 #41 证据链：白名单不分方法 = 写接口免鉴权

`requiresAuth` 的旧实现只有一张 `publicPaths`（**32 条**），前缀命中就 `return false`。它下面那段「区分写方法与 GET」的分支**两个 `return` 都是 `true`**，是彻底的死代码，还和它自己的注释「所有写操作强制认证」正好相反。于是判定退化成：**路径前缀命中 ⇒ 任何方法都放行**。

同一套假 Ollama + 同一份 config 副本，分别用 HEAD 二进制与工作区二进制各跑一遍全量探针（差异只可能来自本次改动）：

| 探测 | BEFORE（HEAD） | AFTER（本批） | 判定 |
|---|---|---|---|
| `POST /api/llm/models/delete` 无 token | **http=200**，`data.code=501 未实现` | **401** `缺少认证信息，请先登录` | 洞已关。BEFORE 那个 200 说明请求**穿过鉴权打到了 llmbiz**，只因函数还是 501 桩才没真删模型 |
| `POST /api/llm/models/download` 无 token | 同上 200/501 | **401** 过滤器措辞 | 同上；未认证即可让服务器去拉模型 |
| `DELETE /api/images/x.png` 无 token | 401 `unauthorized` | 401 **`缺少认证信息，请先登录`** | **措辞变了才是关键**：BEFORE 是 media 适配层自己再查一次 claims 挡住的（防线在错的那一层），AFTER 是过滤器挡的 |
| `DELETE /api/images/x.png` **带** token | 403 `forbidden` | 403 `forbidden` | 未回归：带身份的请求照样穿过过滤器、由适配层判归属 |
| `GET /api/images/x.png` 无 token | 404 `图片不存在` | 404 `图片不存在` | **未过度收紧**：公开图片仍然公开 |
| `GET /api/llm/models` 无 token | 200 + 真模型列表 | 200 + 真模型列表 | 客户端 `mergeTunnelHeaders` 不带 bearer，这条必须继续公开 |
| `GET /api/llm/models/raw` 无 token | 418 + 假 Ollama 标记 | 418 + 假 Ollama 标记 | 终端模式的 `modelsUri()` 靠 `/api/llm/models` **前缀**覆盖，改成精确匹配就会静默 401 |
| `GET /api/images` 无 token（列表） | 401 | 401 | 前缀带斜杠的边界正确：列表要登录，取图才公开 |
| `POST /api/user/login`…`/api/landing/feedback` 共 7 条无 token | 全部非 401 | 全部非 401 | 换 token 之前的引导写流程一条没被误伤 |
| `GET /api/admin/accounts` 无 token | 401 `请先登录管理后台` | 401 `请先登录管理后台` | **删掉 `/api/admin/` 那条白名单零影响**：admin 分支在 `requiresAuth` 之前就仲裁完了 |
| `POST /api/admin/login` | 非 401 | 非 401 | 免鉴权登录未变 |
| 10 条死条目（`/api/platform/config`、`/api/doc`、`/api/media/upload`…） | 404 | **401**（`/api/llm/models-raw` 仍 404） | BEFORE 的 404 已经证明这些路由**全仓不存在**，删白名单条目不影响任何调用方。`models-raw` 仍 404 是因为它被读表的 `/api/llm/models` 前缀盖住、放行后撞上 mux |
| `GET /api/user/login` 无 token | **500** `invalid argument` | **401** | 唯一一处行为收紧。proto 只注册了 `post:`（`api/user/v1/*.proto:783`），Flutter 只在 `api_service.dart:614` POST，全仓零 GET 调用方 |
| #39 回归 `POST /api/llm/chat/raw`、`/api/llm/show/raw` | 418 + 标记 | 418 + 标记 | 未回归 |
| #40 回归 confirm / proactive-deliveries / revoke | 404 `COMPANION_MEMORY_NOT_FOUND` / 200 / 500 guard | 完全一致 | 未回归 |
| 待删接口 `context/preview`、`local-models/catalog` | 501 | 501 | 阳性对照：探针看得见 501，所以上面「不再是 501」的结论有意义 |

汇总计数（同一份探针、同一台机器、间隔 20 分钟）：

| 指标 | BEFORE | AFTER |
|---|---|---|
| 过滤器措辞 `缺少认证信息，请先登录` | 3 | **13** |
| 适配层措辞 `unauthorized` | 1 | **0** |
| 400 CODEC `unregister Content-Type` | 10 | **8** |
| `http=401` | 6 | **15** |
| `http=000`（探针没打到服务，必须为 0） | 0 | 0 |

白名单：**32 条 → 13 读 + 10 写**。删掉 10 条死条目、补 1 条飞书回调，其余按方法归位。

### 26.3 #48 证据链：GET 路由用 body 解码器

Kratos 的 `ctx.Bind(v)` 走的是 **body 解码器**（`transport/http/context.go:100` 的 `srv.decBody`），不是查询串解码器。而 `DefaultRequestDecoder` 在没有 `Content-Type` 时直接回：

```
400 {"code":400,"message":"unregister Content-Type: ","reason":"CODEC","success":false}
```

浏览器重定向打过来的 OAuth 回调 GET 恰恰没有 `Content-Type`。BEFORE 实测三条全中：

| 路由 | BEFORE | AFTER |
|---|---|---|
| `GET /api/auth/feishu/callback?code&state` | **401** 过滤器措辞（白名单里只有 wechat） | **200**，返回「飞书授权」页（`meta refresh` 到 `about:blank`） |
| `GET /api/auth/wechat/callback?code&state` | **400 CODEC** | **200**，返回「微信授权」页 |
| `GET /api/admin/moe/brain/pipeline/stream?agent_key=x`（带 admin token） | **400 CODEC** | **200**，`event: error` + `data:{"code":500,"message":"record not found"}` —— SSE 流起来了，错误来自 `GetBrainPipeline` 查不到这个 agent，**不是解码失败** |

**这里有个必须一起修的陷阱**：飞书回调的 401 与 400 CODEC 是**串联**的两道故障。只把它加进白名单，401 会当场退化成 400 —— 用户看到的还是「飞书登录走不完」，而排查的人会以为白名单已经修好了。所以 #41 与 #48 必须同批验证，不能分开收口。

**为什么不能改用 `ctx.BindQuery`**：它走 `decQuery`，而 Kratos 的 form 编解码器把 tag 名设成了 **`json`**（`encoding/form/form.go:27-30`）。`types.FeishuOAuthCallbackReq` 这些 go-zero 时代的 legacy 结构体**只有 `form` tag**（`internal/legacy/types/types.go:2141-2144, 3807-3810, 579-581`），换过去照样绑不上，只是错误从 400 变成静默空值 —— 更难查。所以改成显式 `r.URL.Query().Get(...)`，并把只剩这一个用途的 `transport/bind.go` 删掉。

回调页把 `code` 回显到 HTML 里，两处都过了 `html.EscapeString`（`oauth_callback.go:41,66`），无 XSS。页面写「授权成功」不是 bug：回调只做**浏览器中继**，真正拿 code 去换用户资料的是后续 `POST /api/auth/{feishu,wechat}/login`。

### 26.4 #49 门禁级缺陷：用例挂在挂钟上

`make check` 在本批第一次跑就红了：

```
--- FAIL: TestPushProactiveOnlyAfterInactivityCooldown
    engine_test.go:535: messages=[], want one interview follow-up
```

连跑三次全红，不是 flake。根因：这条用例用**默认** profile，而默认免打扰窗口是 `1350→450`（`engine.go:1536-1537`，即 **22:30–07:30 UTC**）；`pushProactive` 用 `time.Now().UTC()` 判定（`engine.go:137-141`）。取证时刻是 **UTC 02:31**，`minuteOfDay=151 < 450`，正好落在窗口里 → 直接早退 → `messages` 为空。

| 时刻 | 结果 |
|---|---|
| UTC 17:07（第十二批验证时） | **通过** —— 所以那时 `make check` 是真的绿 |
| UTC 02:31（本批） | **失败** |

也就是说 `make check` **每天有 9 个小时必红、15 个小时绿**，绿灯不代表代码对，红灯也不代表代码错。这与 §25.4 的 `CGO_ENABLED=0` 是同一类问题的反面：那次是「该红的永远绿」，这次是「该绿的周期性红」。两者都让门禁失去意义。

修法与同文件 5 条兄弟用例一致：显式把 `ProactiveQuietStart/End` 置 0。

**顺带挖出一个零覆盖**：修完之后做变异验证，把 `pushProactive` 里的免打扰早退改成恒假 —— **全仓没有任何用例失败**。6 条 `pushProactive` 用例全都把 quiet 置成 0/0，另外两条 quiet 用例只测**钳制与持久化**，没测**推送时的门禁**。原先那条挂钟用例是唯一（且是坏的）覆盖。故补 `TestPushProactiveSkipsInsideQuietHours`：按当前 UTC 分钟现场算出 `[minute-1, minute+3)` 的窗口，因此**不依赖挂钟**；穷举 1440 个分钟验证该推导恒成立且窗口恒为 4 分钟（跨零点时 `start > end`，`inQuietHours` 走 `||` 分支，表达的正是这 4 个回绕分钟）。

### 26.5 登记不修的两条安全缺陷

#### #47 `POST /api/user/reset-password`：免鉴权改任意账号密码

`ResetPasswordReq` 只有 `{ email, new_password }`（`api/user/v1/*.proto:445-448`），**连 code 字段都没有**；`userbiz.ResetPassword` 直接 `FindUserByEmail` 然后覆盖密码，适配层 `user_profile.go:41-46` 也没有任何 actor 校验。实测用**绝不存在的邮箱**取证（用真邮箱会当场改掉别人的密码）：BEFORE/AFTER 都返回 **500 `user not found`** —— 说明未认证请求已经走到查库改密的逻辑里了，且全程零写入。

配套事实：后端**全仓零 SMTP、零验证码存储**；`/api/user/send-reset-code` 与 `/api/user/verify-reset-code` 两条路由**根本不存在**（实测 404），而 Flutter 的 `verify_code_page.dart:49,71` 已经在打它们 —— 找回密码流程在第 2 步就死了，这大概就是这个洞一直没人发现的原因。`api_service.dart:689-693` 的 `resetPassword(email, code, newPassword)` 收了 `code` 参数但**只发 `email` 与 `new_password`**，code 被静默丢弃。

需求方 2026-09-17 原话：「这个暂时不做处理」。三条 reset 前缀**保持在写白名单里、语义一字未改**，并在 `auth.go` 与 `auth_test.go` 各钉了一条注释/用例，让将来真要修的时候必须先动那两行。

#### #50 OAuth `state` 被当回跳地址：开放重定向 + 授权码外泄

`state` 在 OAuth 里本该是 CSRF 随机数，这里被复用成「授权完跳回哪」。链路三段全是公开可达：

1. `GET /api/auth/feishu/authorize-url` 在**公开读白名单**里，`FeishuAuthorizeURL(in.GetState())` 把调用方传入的 `state` **原样**嵌进授权链接（`utils/feishu_oauth.go:42` `q.Set("state", state)`，无校验、无签名、无 HMAC，只在空值时兜底成 `moe_social`）。
2. 回调把它交给 `BuildFeishuOAuthReturnURL(state, code)`，`isAllowedReturnURL`（`utils/feishu_oauth_redirect.go:33-51`）**只校验 scheme**：`http`/`https` 一律 `true`，**完全不看 host**。
3. 命中就 `http.Redirect(302)`，并把授权码挂到查询串上一起送出去。

纯函数实测（不碰网络不碰库）：

| `state` | 飞书 | 微信 |
|---|---|---|
| `https://evil.example/steal` | `https://evil.example/steal?feishu_code=CODE-ABC` | `…?wechat_code=CODE-ABC` |
| `http://attacker.test/a/b?c=1` | `http://attacker.test/a/b?c=1&feishu_code=CODE-ABC` | 同构 |
| `moesocial://feishu/oauth` | 放行（App 深链，符合设计） | 拒绝 |
| `moesocial://otherhost/oauth` | **拒绝**（host 有校验） | 拒绝 |
| `javascript:alert(1)` | **拒绝** | 拒绝 |

完整利用链：攻击者**无需登录**取到 `authorize-url?state=<攻击者站>` → 发给受害者 → 受害者授权 → 服务端 302 到攻击者站并带上**真实授权码** → 攻击者拿它打 `/api/auth/feishu/login` 即可以受害者身份登录（账号接管）。附带缺陷：`state` 被这么用掉之后，整条 OAuth 流程**没有任何 CSRF 防护**（登录 CSRF：可强制受害者浏览器登入攻击者的账号）。

**本批与它的关系必须如实写清**：这个洞在 HEAD 就存在，微信侧一直是公开可达的；**#41 把飞书回调加进白名单之后，飞书侧也变得可达了**。但这不构成回退理由 —— 回调必须公开可达，否则飞书登录根本走不完（那正是 #41 修的 bug）。真正的修法是给 `isAllowedReturnURL` 加 host 白名单，而白名单该收哪些 host（`public_base_url`？两个 `app_return_url`？ngrok 隧道？局域网 IP？）是个策略决定；需求方是多机器开发且明确要求别影响来回切换，故本轮**只登记不修**。

> ↪️ **第十七批已修（#50），上面的实测证据与利用链原样保留作为依据，处置结果见 §30.4。**
> 简述：`state` 字段被完全忽略、回跳改由 `oauth.allowed_return_urls` **精确命中**裁定、授权码封进一次性 ticket（302 只带 `oauth_ticket`/`oauth_state`）、登录须出示 `ticket` + `code_verifier` 并核验 `S256(verifier) == challenge`。
> 实际做法比这里设想的「加 host 白名单」更严：**`app_return_url` 这个配置键连同两个 redirect 文件一起被删除**，白名单该收哪些地址的策略问题改由运维显式维护一份列表来回答。
> 上表那两行 `?feishu_code=` / `?wechat_code=` 现由 `internal/oauthflow/store_test.go` 的 `TestAppendTicketQueryCarriesNoCode` 反向钉住。

### 26.6 判别力声明（每条都靠临时改坏实现验证）

#41/#48 三条新用例（`TestRequiresAuthSplitsReadAndWrite` 30 行、`TestPublicPrefixListsDisjoint`、`TestJWTAuthFilterWhitelistSplits` 7 行）——**双向**变异：

| 变异 | 预期 | 实测 |
|---|---|---|
| **M1** `requiresAuth` 退回不分方法的单表（永远查读表） | 写路由用例变红 | FAIL **12 行**，点名 `POST /api/llm/models/delete`、`/download`、`DELETE /api/images/a.png`，以及 8 条引导写路由 |
| **M2** 从读表删掉 `/api/images/` | 读路由用例变红 | FAIL，精确点名 `GET /api/images/a.png` |
| **M3** 把 `/api/llm/models` 复制进写表（两表重叠） | 结构不变量用例变红 | **三条用例同时红**，`TestPublicPrefixListsDisjoint` 报「同时在 publicReadPrefixes 与 publicWritePrefixes 里：写方法会被重新放行」 |

M1 证明「过度放行」会被抓，M2 证明「过度收紧」也会被抓 —— 只有单向判别力的白名单用例等于没写。`TestPublicPrefixListsDisjoint` 里另有一条防空转断言：两张表任一为空就直接 `t.Fatal`，否则「删光所有条目」会让它绿得毫无意义。

#49 两条用例：

| 变异 | 预期 | 实测 |
|---|---|---|
| **MA** 冷却阈值 `24h → 26h`（日志是 25h 前） | 变红 | FAIL `messages=[], want one interview follow-up` |
| **MB** 每日限额 `>= dailyLimit` → `>= dailyLimit+1` | 变红 | FAIL，`messages` 里出现**两条**同样的追问 |
| **MC** 免打扰早退改成恒假 | 修 #49 之前：**无人变红** | 修之前 rc=0（这就是零覆盖的证据）；补了 `TestPushProactiveSkipsInsideQuietHours` 之后 rc=1，报「免打扰时段内仍然推送了 …，quiet 窗口被无视了」 |

全部变异跑完都做了**逐字节还原校验**（`diff -q` 通过），并 grep 确认 `MUTATION` / `false &&` / `26*time.Hour` / `dailyLimit+1` 残留均为 **0**。

### 26.7 验证汇总

| 项 | 结果 |
|---|---|
| 新增/既有鉴权用例 | **45 PASS / 0 FAIL**（含既有的 `TestJWTAuthFilterAdminPaths`） |
| `make check` | **rc=0，35 包全 ok，0 FAIL，0 SKIP** —— 且这一轮跑在 **UTC 02:3x，正是 #49 的最坏窗口**，所以它证明的比 §25.9 那次（UTC 17:07）更多 |
| `go vet ./internal/server/... ./internal/biz/companion/...` | rc=0 |
| `gofmt -l`（本批触碰的 5 个文件） | 空 |
| 真机 BEFORE/AFTER | 同一份探针、同一套假 Ollama、同一份 config 副本，两个二进制 `cmp` 确认不同；`http=000` 双侧均为 0（探针确实打到了服务） |
| 进程日志（两个二进制各一轮） | `panic=0 fatal=0 reflect_err=0 Unimplemented=0`，端口 18906/18905 复验后均已释放 |
| 路由计数 / openapi | `protoHTTPRouteCount = 316`、openapi **288** 条路径 —— 本批**均未变化**（只改鉴权与解码，没动路由） |
| 共享测试库 | 98 张表全量行数快照，前后 diff **只有 `life_event_logs` +3** |

**+3 行的精确归因**（不宣称「净零」，逐条查清）：这张表 `SHOW COLUMNS` 实测**根本没有 `user_id` 列**，字段是 `world_id / entity_id / entity_type / event_type / description / position_x / position_y / created_at / importance` —— 它是**世界**级事件流，不可能由某个用户的 HTTP 请求直接写入。三行分别是 `world_resource_depletion`、`world_weather_rain`、`wandering`，`world_id=default`、`entity_id` 为 `0` 或 `23743`，时间戳 02:46–02:50 落在两次起服务的窗口内；最近 30 分钟内**没有任何非后台 tick 类型**；探针 uid `999999` 在全部带 `user_id` 的表里均为 **0** 行、`users.id=999999` 不存在、`description LIKE '%probe%'` 为 **0**。结论：全部由 `life_engine_enabled: true` 的后台 tick 产生。

**探针的零副作用约定**：所有「必须非 401」的写路由探针**一律不带 body、不带 Content-Type** —— `jwtAuthFilter` 在路由与解码之前执行，所以只要不是 401 就已证明穿过了鉴权，而 Kratos 的 body 解码器会立刻回 400 CODEC，handler 一行都执行不到。（`register` / `landing-feedback` 若带 `{}` 可能真插入一行，所以统一用这个更保守的打法。）`revoke` 故意用**错前缀**的 `delivery_key` 触发引擎 guard 报错而非成功路径，避免插入 `companion_events`。

### 26.8 本批对方法论的追加

| # | 教训 |
|---|---|
| xiv | **对称注册 + 不对称白名单**：两个回调在 `transport/oauth.go:11-12` 完全对称地注册，白名单里却只有 wechat。只盯白名单看不出问题，必须**把两处注册点并排比** |
| xv | **修好一个 401 可能只是把它变成 400**：串联故障要一路追到 handler 体内。只加白名单的话，飞书回调会从 401 变成 400 CODEC，用户看到的症状一字不变 |
| xvi | **`openapi.yaml` 看不见手写路由与原生路由**：本批复核的 6 类共 40+ 条路由（`/ws/*`、`/api/images/*`、`/api/llm/*/raw`、两个 OAuth 回调、SSE、arena/pet/life/game 全家）**都不在 openapi 里**。只用 openapi 做鉴权审计会漏掉一半攻击面 |
| xvii | **两种 401 措辞是层级判别器**：过滤器说 `缺少认证信息，请先登录`，media 适配层说 `unauthorized`。同一个 401 状态码，措辞不同就说明防线在不同层 —— 「状态码没变」不等于「行为没变」 |
| xviii | **挂钟依赖是门禁缺陷，不是 flake**：连跑三次全红只能排除随机性，排除不了周期性。凡是生产代码里出现 `time.Now()` 的 `Hour()`/`Weekday()`/`Day()` 分支，就要回头查测它的用例有没有钉死时钟 |
| xix | **别把长跑服务与探针串在同一条命令里**：后台进程占住管道 fd → `tail` 一直等 EOF → 工具超时杀掉整个进程组 → 探针全部 `http=000`。必须拆成两次调用，且后台进程 `</dev/null` + 输出重定向到文件 + `disown` |
| xx | **空结果不是干净结果**：归因脚本里三条查询返回空，差点被当成「探针没写库」。实际是列名写错（表里没有 `user_id`）而 stderr 被 `2>/dev/null` 吞了。归因脚本**必须让错误可见** |

### 26.9 需要修订的旧结论

| 旧结论 | 位置 | 修订 |
|---|---|---|
| 路由计数 319 | §25.9 | **316**（`54c5aa45` 删了 3 个必坏 RPC） |
| openapi 291 条路径 | §25.9 | **288** |
| `make check` 34 包全 ok | §25.9 | **35 包**；且那次绿灯跑在 UTC 17:07，**不能证明全天绿** —— 见 §26.4 |
| 用户记忆死 RPC「8 个」 | 前批多处 | **10 个**（`RecordLlmChatTurn`、`AiMemorySettings` 读写两条、`GetContextPreview` 需并入 #42 的清单一起算） |
| 任何声称 `api/etc/moe.yaml` 是 go-zero 死残留的说法 | 前批 | **它是活的**：被当作 `runtime.api_config_fragment` 引用，且是 Agora 凭据的唯一来源。#44 明确**不删** |

### 26.10 下一批（#42）已确认的待删清单

死接口 19 条 + 本批新增 3 条候选，逐条需在删除前**重新验证零调用方**（grep 命中 ≠ 有消费者）：

- **LlmChat 12 条**：`DeleteUserMemory`、`GetAiMemorySettings`、`GetUserMemories`、`GetUserMemoriesDisplay`、`GetUserMemoryProfiles`、`ListLlmLocalModelsCatalog`、`PutAiMemorySettings`、`RebuildUserMemoryEmbeddings`、`RecordLlmChatTurn`、`SearchUserMemories`、`SubmitUserMemoryFeedback`、`UpsertUserMemory`
- **AdminApp 6 条** memory RPC
- **Companion 1 条**：`GetContextPreview`（本批实测仍 501，见 §26.2 阳性对照）
- **`local_models` 整链**（GGUF 下载/清单，#29 的决策落地）
- **本批新增候选 3 条**：Platform 的 `LlmDeleteModel` / `LlmDownloadModel` / `LlmCreateAgent` —— llmbiz 里是 501 桩（`platform_common.go:126-148`），Flutter 与管理台**零调用方**。注意 #41 关掉免鉴权之后，这三条已经没有未认证入口了，删除纯属清理

删完必须重新生成 `.pb.go` + `openapi.yaml` + `routestats/proto_routes_gen.go`，并清空 `adminMemoryRPCsPendingDeletion` / `llmDeadRPCsPendingDeletion` / Companion 测试里的 `"GetContextPreview"` 待删清单。

---

## §27 2026-09-17 第十四批（#42）：死接口整链删除 —— 21 个操作、一个离线模型孤岛、以及一条被探针翻出来的「假成功」

> 落地 §26.10 的待删清单。性质是**纯删除**（无新增能力），但删除范围横跨 proto → 生成物 → 适配层 → biz → service → legacy types → pkg/conf → 两份 YAML → Flutter service → 测试，任何一环漏删都会留下「编译通过但永远 501/404」的残肢。
> 净变化：**43 文件，+1941 / −8868 行**（5 删 40 改）。

### 27.1 删了什么：21 个操作，四族

| 族 | 数量 | 具体操作 |
|---|---|---|
| LlmChat | 12 | `GET/PUT /api/ai/memory/settings`、`POST /api/llm/chat/turn`、`GET /api/llm/local-models/catalog`、`GET/POST/DELETE /api/user/{userId}/memories`、`GET /api/user/{userId}/memories/display`、`POST /api/user/{userId}/memories/feedback`、`GET /api/user/{userId}/memories/profiles`、`POST /api/user/{userId}/memories/reindex`、`GET /api/user/{userId}/memories/search` |
| AdminApp | 6 | `GET /api/admin/memories`、`/health`、`/stats`、`DELETE /api/admin/memories/{memoryId}`、`POST /api/admin/memories/reindex`、`POST /api/admin/learning/export-dataset` |
| Companion | 1 | `GET /api/companion/context/preview` |
| Platform | 2 | `POST /api/llm/models/delete`、`POST /api/llm/models/download` |

三条独立口径互相印证，全部落在 **21**：

| 口径 | before → after | 差值 |
|---|---|---|
| openapi **操作数**（method 级） | 337 → 316 | **−21**，新增 **0** |
| openapi **路径数** | 288 → 270 | −18 ⚠️ |
| `routestats.protoHTTPRouteCount` | 316 → **295** | **−21** |

**路径数为什么少 3**（这是本批唯一一处三个数字不齐的地方，必须解释清楚而不是含糊过去）：消失的 18 条路径里有两条**各自承载多个方法** —— `/api/user/{userId}/memories` 是 GET+POST+DELETE（3 操作 1 路径），`/api/ai/memory/settings` 是 GET+PUT（2 操作 1 路径）。16 条单操作路径 + 1 条双 + 1 条三 = 18 路径 / 21 操作。**只比路径数会漏掉 3 个删除，也会漏掉「同一 path 下只删了半个方法」这种情况** —— 所以复核一律用操作级 diff（脚本 `/tmp` 内 `opsdiff42.py`，按 `path + method` 取集合差）。

### 27.2 §26.10 的清单有一处判断是错的：`LlmCreateAgent` 不能删

§26.10 把 Platform 三条并列成「Flutter 与管理台**零调用方**，删除纯属清理」。实测**只有两条成立**：

| RPC | 客户端调用方 | 处置 |
|---|---|---|
| `LlmDeleteModel` | 零 | ✅ 已删 |
| `LlmDownloadModel` | 零 | ✅ 已删 |
| `LlmCreateAgent` | **`lib/services/llm_api_service.dart:63` → `chat_page.dart:814` 与 `agent_editor_page.dart`，两个活调用点** | ⛔ **保留**，登记 #51 |

删掉它只会把 501 变成 404，用户看到的症状一字不变（甚至更糟，见 §27.5）。这是「grep 命中 ≠ 有消费者」的**反向**教训：**grep 没在 proto 同族文件里命中，也不等于没有消费者** —— 调用点藏在 `llm_api_service.dart` 这个包装层里，按 `LlmCreateAgent` / `createAgent` 搜是搜不到的，得按 **URL 字符串** `/api/llm/agents` 搜。

### 27.3 `local_models` 离线模型孤岛：整链删除（#29 的决策落地）

删除前逐侧验证**四个方向全为零**：后端零路由、外部 Go 零引用（`ResolveLocalModelsStorageDir` / `LoadLocalModelCatalog` / `FindLocalModelByID` / `ParseHTTPByteRange` / `LocalModelMeta`）、Dart 零引用、`moe-admin/src` 零引用。

| 层 | 删除内容 |
|---|---|
| `internal/platform/apicomm/` | `local_models.go`（5181 B）、`local_models_test.go`（435 B，只测 `ParseHTTPByteRange`）**整文件删除** |
| `internal/platform/apiconfig/config.go` | `LocalModels` 字段 + `LocalModelsConf` + `LocalModelCatalogEntry` |
| `internal/platform/wiring/config_override.go` | local_models 覆盖块 + `localModelCatalog()` 辅助函数（净 −30 行） |
| `pkg/conf/config.go` | `Root.LocalModels` 字段 + 两个类型 |
| `config/config.yaml` | `local_models:` 整段（原 `:105-116`） |
| `api/etc/moe.yaml` | `LocalModels:` 片段（原 `:27-31`）。**文件本身保留** —— 它是活的 `runtime.api_config_fragment`，见 §26.9 |
| `legacy/types/types.go` | `LlmDeleteModelReq`、`LlmDownloadModelReq`、`LlmLocalModelCatalogItem`、`LlmLocalModelsCatalogResp` |

**两处不能顺手删的**：

1. `apiconfig.Config` 是用**非严格** `yaml.Unmarshal` 解的（全仓无 `KnownFields` / `UnmarshalStrict`），所以删掉结构体字段后 YAML 里那个键会被**静默忽略**而不报错 —— 这就是为什么 `moe.yaml` 的片段必须一起删，光删 Go 字段会留下一段永远读不到的死 YAML。
2. `config_override.go` 里那段覆盖块**捎带着一条只此一处的历史注释**（mapstructure 下划线键陷阱）。删块即删注释，该陷阱的知识已在 §21.3 留档，此处不再重复。

### 27.4 删除时差点丢掉的三样东西

| 险情 | 怎么发现的 | 处置 |
|---|---|---|
| `wiring/config_override_test.go` 看着像 local_models 的纯脚手架，实际它的 `TestOverridesLeaveFragmentValuesWhenConfSilent` 是 **§21.3「viper 失败不得短路全部覆盖」那个修复的唯一钉子** | 删之前读了文件头注释 | **重写而非删除**：把载体从已删的 local_models 换成今天仍活的 `Image` / `Auth` 两段，并**新增一条反向钉子** `TestOverridesApplyConfValuesOverFragment`。两条都用变异法证明有判别力（无条件写 `MaxBytes` → 第 1 条红；去掉 `LocalDir` 覆盖 → 第 2 条红），随后从备份还原并复验全绿 |
| `pkg/conf` **失去「列表套结构体」这一解码形状的覆盖** | `grep -n "\[\]" pkg/conf/config.go` 只有一处命中 —— `local_models.catalog` 是 pkg/conf **唯一的切片型键** | fixture 里删掉 `local_models:` 块与两条 `Catalog` 断言，并把文件头「覆盖全部形状」的说法**改写成如实陈述缺口**：将来新增列表型键时这里没有现成钉子，需自行补 fixture |
| `auth.go` / `auth_test.go` 的注释与用例把已删的 `/api/llm/models/delete|download` 当作**现行路由**叙述 | 删除后回头读注释 | 不删历史（它解释了读/写分表**为什么存在**），改为标注「已在 #42 删除」，并把承重示例换成今天仍活的 `DELETE /api/images/{filename}`（实测在 `api/media/v1/media_http.pb.go:38` + `protohttp/media/media_http.go:18`）。测试里留一条合成路径 `POST /api/llm/models/any-write` 当探针，钉住「长读前缀下的写方法默认要鉴权」 |

`legacy/types/types.go` 同族里 **`AdminMemoryTypeStat` 必须保留**：`AdminAnalyticsOverviewData.MemoryByType` 引它，`apicomm/admin_insights.go` 在活路径上填充（真机复验 `GET /api/admin/analytics/overview` → 200 即为证）。删掉的那 9 个类型逐个用「打印全部实际命中 + 阳性对照」的脚本复核为真零引用。

### 27.5 真机复验：30 项全过，但探针翻出一条比 #51 原记录更严重的缺陷

判据设计：`jwtAuthFilter` 在路由匹配**之前**执行，未带 token 的请求无论路由是否存在都回 401，**401 分不出「路由还在但要登录」和「路由已删」**。所以必须带合法 token 穿过过滤器才能拿到路由器真正的 404（一次性 token 工具放在 `backend/_tokengen/` 下划线目录，`go ./...` 会忽略，**验完即删，不入库** —— `backend/_probe/mint/main.go` 曾在 `54c5aa45` 里被误提交，这次是显式删除的）。

| 组 | 项数 | 结果 |
|---|---|---|
| 阳性对照（不存在的路径必须 404，否则整个判据失效） | 2 | 用户侧 + 管理侧均 404 ✅ |
| 21 个已删操作必须 404 | 21 | **全 404** ✅ |
| 7 条存活路由必须非 404 | 7 | 全非 404 ✅（`/health` 200、`/api/llm/config` 200、`/api/admin/analytics/overview` 200、`/api/companion/profile` 200、`/api/ai/providers` 200） |
| 无 token 必须仍 401（验证 #41 分表未被本批削弱） | 3 | 全 401 ✅，其中 `POST /api/llm/models/delete` 的 401 证明读/写分表在路由已删的情况下仍生效 |

**汇总 `pass=30 fail=0`。** 但「非 404」这个判据本身不够 —— 两条存活路由的返回值与预期不符，逐个查了响应体：

1. `GET /api/llm/models` → **500** `{"code":500,"message":"Get \"http://192.168.124.77:11434/api/tags\": context deadline exceeded"}`。**环境性**，非回归：n100 的局域网 Ollama 在本机不可达，路由与适配层接线正确。
2. `POST /api/llm/agents` → **HTTP 200**，响应体：
   ```json
   {"code":200,"data":{"code":501,"message":"未实现"},"message":"操作成功","success":true}
   ```
   我原先给 #51 记的症状是「chat_page 每次必弹**红色**错误」—— **这条记录是错的，真实症状更糟**：

   - Go 侧 `platform_llm.go:37` 是 `return platformWriteToBaseResp(result), nil` —— **error 恒为 nil**，501 被塞进 `BaseResp` 当**载荷**，于是外层信封是 `code:200 / success:true / "操作成功"`。
   - Dart 侧**只看外层**：`api_service.dart:483`（`result['success'] == false` 才抛）、`:492`（HTTP 状态码 2xx 即放行）、`:498` 原样返回整个信封；随后 `llm_api_service.dart:68` 的 `ApiResponse.isSuccess(result)`（`api_response.dart:7-13`）读的也是外层 `success` 与 `code`，`200` 属白名单 → **返回 true**。
   - 结果：`chat_page.dart:817` 弹的是**绿色成功提示** `'系统提示词已更新并同步到服务器模型（已开启新对话）'`，而服务器模型**从未被创建**。用户被明确告知成功了。

   `platformWriteToBaseResp` 目前**只有这一个调用点**，所以现在是 1 处而非一类；但「适配层把业务失败当载荷返回、客户端只校验外层信封」这个**组合**是系统性的，任何新增的同形适配方法都会继承这个假成功。#51 已据此改写描述与严重度。

### 27.6 门禁与验证记录

| 项 | 结果 |
|---|---|
| `go build ./...` | rc=0（每一步删除后各跑一次） |
| `go vet`（全部触碰包） | rc=0 |
| `make check` | **rc=0，35 包 ok，0 FAIL，0 SKIP** |
| `flutter analyze` | 38 条 info，**0 error / 0 warning**，无一条落在本批触碰的文件里（`grep -in companion` 空） |
| `flutter test test/companion_service_test.dart` | rc=0，**14/14** |
| `adapter_coverage_test.go` | 两份待删白名单清空后 `pending` 字段对 28 个 service 全 nil，**连字段一起摘掉** → 28 个 service 一律零豁免 |
| `companion_adapter_test.go` | 不再豁免 `GetContextPreview` |
| `gofmt` | 本批触碰文件中有 2 个不干净（`internal/biz/llm/platform_common.go`、`internal/service/llm/llm.go`），已用 `gofmt -d` 对比 `git show HEAD:` 版本确认**字节级同差异 = 历史遗留**，留给 #45 统一扫，避免污染本批 diff 的可归因性 |

**一次假警报，值得记下来**：`make gen-proto-route-count` 重写 `proto_routes_gen.go` 后紧接着跑 `make check`，得到 rc=2 与 `FAIL backend/internal/server/routestats [build failed]`，**日志里一条编译器诊断都没有**。没有当成真失败也没有当成噪声：`go vet ./internal/server/routestats/` 干净、单独 `go test` 该包 ok、读 Makefile 确认 `check` 实际跑什么，再跑一次 `make check` → rc=0 全绿。判定为**代码生成物刚被改写导致的构建缓存陈旧产物**。

### 27.7 本批对方法论的追加

| # | 教训 |
|---|---|
| xxi | **openapi 复核要比「操作数」而不是「路径数」**：一个 path 可以挂 GET+POST+DELETE 三个操作。本批路径数 −18 而操作数 −21，差值 3 全藏在两条多方法路径里；只看路径数既会少算删除量，也看不出「同 path 下只删了半个方法」 |
| xxii | **「非 404」不足以证明一条路由是健康的**：`POST /api/llm/agents` 以 HTTP 200 通过了存活检查，载荷里却写着 501。存活探针**必须连响应体一起看**，否则会给一个正在对用户撒谎的接口盖「正常」章 |
| xxiii | **代码生成后紧跟门禁可能报无诊断的 `[build failed]`**：先把该包单独 build/vet/test 一遍再决定是重跑还是真修，别直接采信也别直接忽略 |
| xxiv | **删除测试文件前先读它的文件头注释**：一个看着纯属已删功能脚手架的测试，可能是另一条老修复（§21.3）的唯一钉子。删掉它不会有任何报错，只会在将来静默失去保护 |
| xxv | **「grep 没命中」同样不是结论**：`LlmCreateAgent` 按 RPC 名/驼峰名在 Dart 侧搜不到调用方，真实调用点藏在 `llm_api_service.dart` 包装层里。判定死接口要按 **URL 字符串**搜，而不是按符号名 |
| xxvi | **删掉唯一的切片型配置键会顺带删掉一种解码形状的覆盖**：删键之前先看它是不是某个类型形状（列表/嵌套/指针）的唯一载体，是就得把「不再覆盖」写进 fixture 注释，别让文件头继续宣称全覆盖 |

### 27.8 需要修订的旧结论

| 旧结论 | 位置 | 修订 |
|---|---|---|
| 路由计数 316 / openapi 288 条路径 | §26.7、§26.9 | **295** / **270 条路径（316 个操作）** |
| Platform 三条 RPC 均「零调用方，删除纯属清理」 | §26.10 | **`LlmCreateAgent` 有 2 个活调用点，已保留**，见 §27.2 |
| #51 症状「每次必弹红色错误」 | #51 登记项 | **实为绿色成功提示 + 静默假成功**，见 §27.5 |
| 离线模型链路「删除还是补活」待定 | #29 | **已决策并落地：整链删除**，#29 可关闭 |
| `pkg/conf` fixture「覆盖全部形状」 | `pkg/conf/conf_test.go` 头注释 | 已改为如实陈述：**列表型形状不再被覆盖** |

---

## §28 2026-09-17 第十五批（#19）：把两个编译期常量搬进配置 —— 以及差点顺手把世界节奏改快 60 倍

> 落地 §16.4 登记的建议。§16.4 指出「周期 tick」这一个概念在仓里有**四处硬编码 + 两处可配**，且没有任何文档解释为什么 `bot_scheduler` / `dream_scheduler` 可配而 Life / Game 引擎不可配。本批把**生效的**那两处硬编码接上 `pkg/conf`，并顺带清掉一个此前没人发现的第三份副本。
> 净变化：**7 文件**（`pkg/conf/config.go`、`pkg/conf/derive.go`、`pkg/conf/conf_test.go`、`internal/platform/moewiring/api_life.go`、`internal/platform/moewiring/api_game.go`、`internal/service/game/game.go`、`config/config.yaml`），零删除文件。

### 28.1 §16.4 的建议与实际落地的三处偏差（记下来，别被当成漏做）

| §16.4 原建议 | 实际落地 | 为什么偏 |
|---|---|---|
| 键名 `moe.life_tick_interval_seconds` / `moe.life_flush_interval_seconds` / `moe.game_world_tick_interval_seconds` | `moe.life_tick_seconds` / `moe.life_flush_seconds` / `moe.world_tick_seconds`（`config.go:210,211,217`） | 同段已有 `bot_scheduler_tick_seconds` / `dream_scheduler_tick_seconds` 的先例，`_interval_` 是冗余词；`game_` 前缀也去掉，`moe.` 段下没有第二个「世界」 |
| `world_runner.go` 与 `types.go` 的默认值「都改为引用它」 | **两处都保持原样** | 见 28.2 / 28.3：照原建议做会造出第三、第四份副本，正是本批要消灭的东西 |
| 一个统一解析方法 | **两个契约相反的函数**：`LifeIntervals()` 未配置返回 300s，`WorldTickInterval()` 未配置返回 **0** | 见 28.3：契约不同不是不一致，是「让每个数在仓里只存一份」的必然结果 |

### 28.2 差点犯下的 60 倍回归：`lifebiz.DefaultConfig()` 是 5 **秒**，不是 5 分钟

第一版 `LifeIntervals()` 写的是「未配置返回 0，让下游兜底」—— 直觉上最干净（配置层不该知道业务缺省值）。它会静默把世界节奏改快 60 倍：

```
conf.LifeIntervals() 未配置 → 0
  → lifeapp.Config{TickInterval: 0}
    → lifeapp.engineConfig() 的 `if config.TickInterval > 0`（life.go:69）不成立，不覆盖
      → 保留 lifebiz.DefaultConfig() 的值
        → types.go:41 = 5 * time.Second   ← 5 秒，不是 5 分钟
```

生产路径**从来都是** `moewiring` 显式传 300 秒把那个 5 秒盖掉的（§16.4 的表里就标着「✗ 被覆盖」）。也就是说 biz 层的 5 秒不是「生产缺省值」，是**单元测试用的引擎缺省**。所以：

- `defaultLifeInterval = 5 * time.Minute` 落在 `derive.go:36`，缺省值必须在配置层显式给出（`derive.go:299`）。
- `types.go:41,44` 的 5 秒**故意不动**，它继续只服务于单元测试。
- 钉这条的用例叫 `TestLifeIntervalsNeverFallThroughToBizDefault`（`conf_test.go:734`），函数名直接写明它在防什么。

> **教训**：`TickInterval: 5 * time.Second` 与 `livingWorldIntervalSeconds = 5 * 60` 里那个「5」是完全不同的量级，而 §16.4 的表格把前者标为「✗ 被覆盖」时也没写出它的单位含义。要读**那一层的实际数值和单位**，不要读变量名，也不要直接采信上一份文档的结论。

### 28.3 顺带发现的第三份副本：`service/game/game.go` 里另一个 45 秒

`gamebiz.defaultWorldTickInterval = 45 * time.Second`（`world_runner.go:13`）本来是唯一副本，`StartWorldRunner` 的 `if interval <= 0`（`:20-21`）是它的兜底守卫。但 `internal/service/game/game.go` 的 `New()` 里**直接硬编码 `45*time.Second` 传进去**，于是：

- 45 这个数在仓里有两份；
- `interval <= 0` 那条守卫**永远不可达**，等于死代码。

处置：`Deps` 增加 `WorldTick time.Duration`（`game.go:22`），`New()` 原样转交给 `StartWorldRunner`（`game.go:33`），`moewiring/api_game.go:30` 填 `conf.WorldTickInterval()`。而 `WorldTickInterval()` **未配置时返回 0**（`derive.go:308-312`），让 biz 层那条守卫重新可达、45 只存一份。

这就是两个函数契约**必须相反**的原因：Life 的下游缺省值量级是错的（5 秒），配置层必须显式兜底；Game 的下游缺省值是对的（45 秒且只此一份），配置层必须让位。两处理由都写进了函数注释，否则后来者会把这种「不一致」当不整洁去统一，副本随之复活。

### 28.4 观测点选启动日志，不选 `/ws/life`

真机复验原本想用 `/ws/life` 的广播频率当可观测量（tick 变快 → 消息变密）。放弃：`transport/websocket.go:29` 那条路由**不在 `publicReadPrefixes` 里**，探它需要有效 JWT，等于又要造一次性 token 工具（§27.6 刚把上一个删掉）。

改成在 `api_life.go:30` 打一行启动日志，且**打的是换算之后真正交给引擎的那两个整数**，不是 `conf` 返回的 `Duration`：

```go
tick, flush := conf.LifeIntervals()
tickSec, flushSec := int(tick/time.Second), int(flush/time.Second)
moelog.Infof("life: engine intervals tick=%ds flush=%ds (moe.life_tick_seconds / life_flush_seconds)", tickSec, flushSec)
```

第一版打的是 `tick` / `flush` 本身，那样证明不了 `int(tick/time.Second)` 这个换算写对了没有（漏掉 `/time.Second` 会打出纳秒数，而 `Duration` 用 `%d` 同样是个大整数，看日志的人未必能立刻察觉）。现在这一行同时证明两件事：**配置读到了** + **秒数换算对了**，而且对运维长期有用。

### 28.5 验证记录

**① 变异测试（证明新断言有判别力，不是摆设）**

| # | 变异 | 预期变红的用例 | 实测 |
|---|---|---|---|
| M1 | `derive.go:299` `return defaultLifeInterval` → `return 0` | `TestLifeIntervalsNeverFallThroughToBizDefault` | ✅ FAIL |
| M2 | `derive.go:312` `return 0` → `return 45 * time.Second` | `TestWorldTickIntervalUnsetMeansZero` | ✅ FAIL |
| M3 | `config.go:210` tag `life_tick_seconds` → `life_tick_second`（少一个 s） | `TestRealConfigYAMLLoads` + `TestLifeIntervalsNeverFallThroughToBizDefault` | ✅ 两条都 FAIL |

M3 是既有纪律的直接应用：**mapstructure tag 写错一个字母不会报错，只会静默拿到 0**（§17.6(c) 那一类）。所以 `TestRealConfigYAMLLoads` 里新增的断言（`conf_test.go:506`）不查「字段存在」，而查**真实 `config.yaml` 里这三个键确实解出了非零值**。三次变异后都用 `cmp` 逐字节确认还原，还原后重跑全绿。

**② 真机双跑对比（同一个二进制，两份配置，两个不同输出）**

| 跑 | 命令 | 配置里的值 | 启动日志 |
|---|---|---|---|
| A | `/tmp/moe19 -f config/config.yaml` | `life_tick_seconds: 300` / `life_flush_seconds: 300` | `life: engine intervals tick=300s flush=300s` ✅ |
| B | `/tmp/moe19 -f /tmp/life19/config.yaml` | `30` / `45` | `life: engine intervals tick=30s flush=45s` ✅ |

两次输出不同 ⇒ 这三个键是**活的**，不是装饰 —— 正是 §0 第 4 行「改 yaml 可能不生效」要防的失败模式。两跑均**未传 `-migrate`**（日志第 2 行 `已跳过 AutoMigrate` 为证），跑完立即 `pkill` 并用 `pgrep` 确认无残留进程（rc=1）：后端连的是**共享测试库**，`life_engine_enabled: true` 会持续往 `life_event_logs` 写行。

> 跑 A 的日志里另有 `life: dedupe removed duplicate "团子" id=23749 (keep=23743)`，这是引擎自身的启动去重（第十二批 §22.7 的产物），非本批引入。

**③ 门禁**

| 项 | 结果 |
|---|---|
| `go build ./...` | rc=0，日志为空（rc 直接取，不经管道，见 28.6 xxx） |
| `make check` | **rc=0 · 35 ok · 0 FAIL · 0 个真 `--- SKIP`** |
| `gofmt -l`（6 个 `.go` 改动文件） | 空 |
| 一次性产物 | `/tmp/moe19`、`/tmp/life19/`、变异脚本与 `.bak` 全部删除，未入库 |

### 28.6 本批对方法论的追加

| # | 教训 |
|---|---|
| xxvii | **「未配置就返回 0，让下游兜底」不是天然安全的做法**：先去读下游兜底值的**实际数值和单位**。本批下游是 5 *秒*，而我（和 §16.4 的表格）都当成 5 *分钟*，差 60 倍且全程无报错 |
| xxviii | **同批新增的两个配置函数可以有相反的契约**，只要各自都让某个数在仓里只存一份。「不一致」不是缺陷，「副本」才是；但必须把为什么相反写进函数注释，否则会被后来者当不整洁统一掉，副本随之复活 |
| xxix | **优先选「打印真正交给下游的那个值」当观测点**：一次证明配置读到了 + 单位换算对了，还长期服务运维。选运行时行为当观测点通常更贵（要鉴权 / 要等一个周期 / 会往共享库写数据），证明面还更窄 |
| xxx | **门禁的 rc 不能从管道后面取**：`go build ./... 2>&1 \| head -20; echo "rc=$?"` 里的 `$?` 是 `head` 的退出码，实测在构建真失败时打出 `rc=0`。与 xxi 同族 —— 重定向到文件再单独取 rc |

### 28.7 本批未做 / 遗留

- `moe.world_tick_seconds: 45` 已写进 `config/config.yaml:188`，值与 `gamebiz.defaultWorldTickInterval` 相同。这不构成副本（yaml 里是给运维看的当前生效值，代码里的是缺省），但意味着「改这一行」和「不改」目前等价。真要调 game 节奏时改 yaml 即可、不必重新编译 —— 这正是本批的目的。
- §16.4 说的「四处硬编码」中，另两处（`types.go:41,44` 的 5 秒、`world_runner.go:13` 的 45 秒）**故意保留**，理由见 28.2 / 28.3。
- **本机磁盘 180 GB / 228 GB（97%）**：本批构建时先撞上 `link: mapping output file failed: no space left on device`（当时仅剩 319 MiB）。清理只做了 `go clean -cache`（可再生，释放 7.1 GB），**没有**动 module cache、`backend/bin/moe-social`(33M)、`build/*.dill`(80M) 或任何非 Go 数据。剩余压力不是本次改动能解决的，需需求方自行排查，否则后续构建 / Flutter 运行会继续随机失败。

---

## §29 2026-09-17 第十六批（#43）：三份同源的 URL 规范化、九处 GBK 乱码、以及一个被档位闸放行的幽灵工具

**基线**：与 §27 / §28 同一基线 + 工作区改动（#19 / #42 / #43 均未提交）。
**性质**：配置治理的代码级残项收口。#43 原登记四项，本批完成三项（乱码 / `trimURL` 去重 / `tier` 死工具名）；
第四项（gradle 签名口令兜底 = #16）**仍未做**，理由见 29.8。

### 29.1 一句话结论

三件事不是三个孤立的脏活，而是**同一个缺陷的三种形态：仓里对同一事物存在两份以上各执一词的描述，且分叉时不报错**。

| 形态 | 两份（以上）描述 | 分叉时的表现 |
|---|---|---|
| URL 规范化 | 三份逐字节相同的副本 + 第四份兜底值不同的近似副本 | 管理台显示的地址、客户端拿到的基址、后端拼出的地址三者不一致，图片全裂但无报错 |
| 档位闸 | `tier.go` 的 `AllowsTool` vs `tools/registry.go` 的注册表 | 请求先过档位闸、再在 `Execute` 的 `default` 分支以「未知工具」失败 —— 失败原因被归到档位之外，排查方向错 |
| 文档 | `Moe-Intelligence-Stack-v1.md` §4 的工具清单 vs 真实注册表 | 清单列了 5 个不存在的工具，读者照它去调 |

### 29.2 GBK 乱码：§25.7 登记 5 处，实测 **9 处 / 4 文件**

| 文件 | 处数 | 可见性 | 内容 |
|---|---|---|---|
| `backend/internal/service/companion/companion_api.go` | 3（`:374`、`:378`、`:385`） | **终端用户可见**（Kratos HTTP 错误的 `message`，直接进 App 弹窗） | `COMPANION_UNAVAILABLE` / `COMPANION_PROACTIVE_NOTIFICATION_INVALID` / `COMPANION_PROACTIVE_NOT_FOUND` |
| `backend/deploy/config/config.go` | 3（`:53`、`:56`、`:100`） | 运维可见（部署 agent 启动失败信息） | 读取 / 合并 `config.local.yaml`、`workspace_root` 无效 |
| `backend/internal/server/protohttp/adminapp/adminapp.go` | 2（`:13`、`:23`） | 仅源码注释 | **二次损坏**，机械恢复不可行，按上下文重写 |
| `lib/pages/checkin/checkin_page.dart` | 1（`:826`） | **终端用户可见**（签到页进度文案） | `'$completedCount / ${tasks.length} 完成'` |

§25.7 只登记了 `deploy/config/config.go` 那一类「运维可见」的，**两处终端用户可见的（companion 的 HTTP 错误、签到页文案）它完全没提** —— 影响面比文档记载的严重。

**恢复正确性的独立证据（比「检测器归零」强得多）**：`companion_api.go` 在 HEAD 上就有**同一条**消息的两个副本 —— `:28` 是干净的 `伙伴服务暂不可用`，`:405` 是乱码的 `浼欎即鏈嶅姟鏆備笉鍙敤`。恢复后的 `:374` 与 HEAD 就干净的 `:28` **逐字节相同**（UTF-8 字节串比对为 `True`）。也就是说这次恢复有一个仓内自带的可信参照物，不是靠我的推断。

**检测器走了两版弯路**，两版都错，且错的方向相反：

| 版 | 规则 | 结果 |
|---|---|---|
| v1 | 严格往返 + `常见汉字占比 > 0.05` 才报 | **漏报**：9 处只浮出 1 处（`读取` 二字不在我那 50 个「常见字」集合里）；同时「疑似」兜底桶灌进 **6348 条假阳性**（全是正常中文） |
| v2 | 去掉占比闸，只要严格往返成功就报 | **误报**：短串上把干净中文判成乱码 —— `统一` 的 gb18030 编码恰好是 2 个非汉字符的合法 UTF-8（`ͳһ`），往返**成功** |
| v3（最终） | 追加方向判据：`恢复结果的汉字数 >= 原串汉字数 × 0.6` | **7 行命中、0 假阳性**，并翻出两个文档从未登记过的文件 |

v3 的判据来自乱码的成因本身：**乱码恢复回中文，干净中文恢复不回中文**（会变成西里尔/拉丁字母或直接解码失败）。v2 的错误在于只问「往返能不能成」，没问「往返成了之后得到的是不是中文」。

余下 2 处（`adminapp.go` 的两条注释）是**二次损坏**：原始字节里有 ASCII `?`（丢字节留下的），严格往返必然失败，v3 也扫不到，靠有损 `replace` 恢复 + 上下文重写定位。故 `7 + 2 = 9`。

**根因是 Windows 编辑器指纹**，不是某次误操作。全仓扫描：

| 类型 | 文件 | 是否已跟踪 |
|---|---|---|
| UTF-8 BOM | `moe-admin/build-out.txt` | ✅ 已跟踪，且**是被 gitignore 漏掉的构建产物**（归 #46） |
| UTF-8 BOM | `backend/deploy/config/config.go` | ✅ 已跟踪 |
| UTF-8 BOM | `assets/pet/lpc/README.md` | ✅ 已跟踪 |
| **双重 CR**（`\r\r\n`，非普通 CRLF） | `backend/internal/service/game/game_session.go` | ✅ 已跟踪 |

四个都留给 #45：`gofmt -w` 会顺带剥 BOM、并把行尾归一为 LF。**本批故意不碰** —— 见 29.3 末尾那条 `gofmt` 判定。

> `game_session.go` 那个要说清楚，因为它不是普通 CRLF：实测 **111 个 CRLF + 112 个孤立 CR + 0 个孤立 LF**，即每行以 `\r\r\n` 结尾（一次 LF→CRLF 转换被应用了两遍）。这意味着 **`dos2unix` 治不了它** —— 该工具只把 CRLF 换成 LF，会留下 112 个孤立 CR。`gofmt` 能彻底归一：实测输出 **0 个 CR**、111 个 LF、体积 3708 → 3485 字节；且 `gofmt -l` **本来就报这个文件**，所以 #45 的批量 `gofmt -w` 会顺手治好它，不需要为它单独做什么。

**编码修改手段**：乱码字节**无法重新敲进 `Edit` 的 `old_string`**，`Edit` 一律报「0 occurrences」。改用脚本按 (路径, 行号) 定位，并在写入前断言「该行把每段非 ASCII 换成 `|` 之后的骨架」与预期相等 —— 行号错一位就中止，而不是把代码改坏。

### 29.3 `trimURL`：不是两份，是**三份**；还有第四份故意不并

§28 之前我只知道 `pkg/conf` 与 `utils/admin_runtime_config.go` 各有一份。本批顺着 `/api/public/client-config` 往回追，发现**第三份**：`internal/biz/appcfg/public.go` 的 `NormalizePublicAPIBaseURL`。三份的「TrimSpace + 循环去尾斜杠」逐字节相同，规范化的是**同一批** `public_base_url` 值。

处置：导出 `conf.TrimURL`（函数体保持逐字节不变，零行为风险），后两份全部委托到它。`utils` 侧 6 个调用点、`appcfg` 侧 1 个调用点。

**第四份近似副本刻意没并**：`internal/biz/media/image.go:66` 的 `normalizeBaseURL` 用 `TrimRight(..., "/")`（与 `TrimURL` 等价），但**兜底值不同** —— 它回落到硬编码 `http://localhost:8888`，而 `conf.ImagePublicBaseURL()` 回落到 `api.public_base_url`。也就是说 `image.public_base_url` 为空时，图片外链存在两个互相矛盾的根。合并它等于改线上图片地址的行为，属 **#44（`public_base_url` 单点派生）** 的范围。这一点已写进 `TrimURL` 的函数注释，避免后来者以为漏了。

> **本批引入的唯一行为变更**（刻意，且已真机验证，见 29.5）：`NormalizePublicAPIBaseURL` 旧实现**先判空、后去斜杠**，输入 `"/"` 会返回 `("", nil)` —— 客户端拿到 HTTP 200 和一个空基址，静默拼不出任何请求。改为委托 `TrimURL` 后顺序变成先去斜杠、后判空，`"/"` 走 `ErrNoPublicAPIBaseURL`，与调用方 `platform.go` 早已存在的 404 分支一致。新增 `internal/biz/appcfg/public_test.go`（该包此前**零测试覆盖**）9 例，其中 2 例专盯这个变更。

**`gofmt` 判定**：改完后 `gofmt -l` 报 `deploy/config/config.go`。没有顺手「修」它，而是先定性 —— `gofmt -d` 显示抱怨的是 **UTF-8 BOM** 与结构体字段对齐，且 `git show HEAD:backend/deploy/config/config.go | gofmt -l` **同样报它**，证明该文件在 HEAD 就不洁，属 #45 的批量重排范围。在一个语义批次里混进整文件重排，会让 diff 无法审阅。

### 29.4 `AllowsTool` 的幽灵工具名：补完 §25.7 没追完的调用方

§25.7（`:2586` 那行「没删」）当时的原话是：*「`AllowsTool` 可能被喂进历史审计记录里的旧工具名，我没有追完全部调用方，不拿猜测当结论」*。这个谨慎是对的，但它把一项零风险清理挂住了整整四批。本批把追踪补完：

| 环节 | 事实 |
|---|---|
| `AllowsTool` 的调用方 | **恰好 2 个**：`tools/executor.go:33`、`toolaudit/record.go:90` |
| 两处喂进去的名字来自哪 | 都来自 `tools.OpenAISchemaList()`，即注册表（**恰好 5 项**） |
| 历史审计行会不会被喂进来 | **不会**。`flow_run.go:80-114` 只可能把 `post_create` 交给 `Execute` |
| 唯一可观测差异 | 一条**本就在失败**的路径上的错误文案：`未知工具: X` → `档位 s2 不允许工具 X`，两者 `OK:false` |

于是摘掉 `memory_search` / `memory_get` / `memory_save`，`tier.go` 从 48 行到 51 行（`AllowsTool` 现在在 `:38-51`）。

**新增回归钉 `TestAllowsToolNeverPermitsUnregisteredTool`，并用变异证明它补的是旧套件的盲区**：

| 变异 | 新用例 | 既有 `TestBuildSchemaItemsCoversAllTools` |
|---|---|---|
| 把 `memory_search` 加回 `tier.go` 的 S1/S2 分支 | **FAIL**（`record_test.go:116: s1 放行了注册表里不存在的工具 memory_search`） | **PASS** |

右列的 PASS 是直接证据：**这个缺陷在门禁面前隐形了四批**。原因是既有用例只从注册表往档位查（「注册表里的工具至少有一档放行」），而反向的「档位放行的 ⊆ 注册表」查不到 —— `AllowsTool` 是对任意字符串的谓词，无法枚举它放行了哪些名字。所以新用例显式探测真正发生过分叉的那三个名字，并前置断言它们**不在**注册表里（若哪天重回注册表，用例会要求重挑探测名单，而不是静默失效）。变异后 `cmp` 逐字节确认还原，还原重跑全绿。

> `moe-admin/src/lib/moeToolLabels.ts:4-6` 的这三个中文标签**故意保留**：`moe_tool_calls` 表里存着它们还能被调用时留下的历史行，去掉标签会让旧记录显示成裸名字。

### 29.5 连带修正的文档失真（同一缺陷的第三种形态）

`docs/dev/Moe-Intelligence-Stack-v1.md`：

| 位置 | 原文 | 处置 |
|---|---|---|
| §2 档位表 | 引 `tier.go:32-45`，S1 行含 `memory_search`/`memory_get`，S2 行含 `memory_save` | 改为 `:38-51`，两行按注册表重列，S2 标注「= 注册表全集」，并加一段注册表不变量说明 |
| §4 工具清单 | 8 行，其中 `memory_search`/`memory_save`/`memory_get` 标为「已实现的 L1 工具」 | 砍到与注册表逐项相等的 5 行。这三个是**双重死项**：① 注册表从来没有过它们；② 它们声称调用的用户记忆 RPC 已在 #42 整链删除 |
| §4 尾句 | 「`memory_list` / `memory_read_daily` 仍由 Flutter 本地工具处理；v2 迁入 Executor」 | **实测为假**，已改写（见下） |
| §2 死键警告 | 引 `config/config.yaml:184` | 改为 `:171`，并注明行号是**上移**的（`local_models` 整块 13 行在 #42 被删），#19 新增的三键在它下面、不影响此行号 —— 防止后来者照 `:184` 改回去 |

**顺带翻出一整篇死文档**：`docs/dev/local-llm-tools.md` 描述的 Flutter 本机 GGUF 工具链**完全不存在**。正向对照通过（`post_search` 能命中 1 文件），而 `pubspec.yaml` 里没有 `llamadart`，`lib/` 下 `MoeLlmMemoryTools` / `LocalLlmChatService` / `AiMemoryTools` / `builtinLocalGguf` / `local_gguf` **逐个都是 0 文件**（`AiChatGatewayService` 确实存在于 7 个文件，但没有 `local_gguf` 分支）。客户端侧唯一真源是 `lib/services/ai_tool_runtime.dart:29-33` 的 `registeredToolNames()`，只注册 `post_search` / `post_get`。

§3 的 8 条 API 路径**逐条实测存在**（6～8 个文件命中），无需修正。

### 29.6 验证

**① 变异（判别力）**

| # | 变异 | 期望 | 实测 |
|---|---|---|---|
| M1 | `memory_search` 加回 `tier.go` 的 S1/S2 分支 | 新用例红、旧用例绿 | ✅ 新 `FAIL`（`record_test.go:116`）／旧 `PASS` |
| M2 | `NormalizePublicAPIBaseURL` 恢复旧判据顺序（先 `TrimSpace` 判空、后去斜杠） | 只有 `"/"` 与 `"///"` 两例红 | ✅ 恰好 2 例 `FAIL`，均为 `err = <nil>`；其余 7 例绿（它们对顺序不敏感，符合预期） |

两次变异后都用 `cmp` 逐字节确认还原（`cmp: BYTE-IDENTICAL`），并确认变异时临时加的 `strings` 导入已随之消失。

**② 真机（含一次误启动的教训）**

| 跑 | 配置 | `GET /api/public/client-config` |
|---|---|---|
| A | 真配置 `public_api_base_url: "http://47.106.175.49:8888"` | `200` · `{"api_base_url":"http://47.106.175.49:8888"}` · `message:"操作成功"` |
| B | 探针配置（**只改一行**）`public_api_base_url: "/"` | **`404`** · `{"reason":"NO_PUBLIC_API_BASE_URL","success":false}` |

跑 B 一次证明了三件事：**①** `conf.TrimURL` 确实拿到了**未加工的**配置值（`"/"` 只有被去掉斜杠才会变空，否则会以 `"/"` 原样返回 200）；**②** 判空现在在去斜杠**之后**（即 29.3 那个刻意的行为变更真的生效）；**③** `platform.go` 的错误映射把它变成了 404 而不是 200 包空值。因此**不必再单独跑一次 `///`** —— 跑 B 已经把「去斜杠在真机上生效」证完了。

跑 A 的 `message:"操作成功"` 还顺带证了一件本批需要的事：**HTTP 传输层不会把中文再弄成乱码**。所以 29.2 那 9 处纯粹是源文件编码问题，改完即彻底，不存在「源码对了、出口又坏」的残留风险。

两跑日志均含 `已跳过 AutoMigrate`（未对**共享测试库**传 `-migrate`），跑完立即 `kill` + `pkill` 并用 `pgrep` 确认（rc=1）。

> ⚠️ **跑 A 是误启动的**：我以为 `make moe-social` 是构建目标，实际它是 `go run ./cmd/moe-social`（`Makefile:76-77`）—— **一条不会返回的服务器启动命令**。结果一个连着共享测试库、`life_engine_enabled: true` 持续往 `life_event_logs` 写行的进程被我挂了 **21 分钟**才发现。发现后立即探针 + 击杀。教训记入 29.7 xxxi。

**③ 门禁**

| 项 | 结果 |
|---|---|
| `make check` | **rc=0 · 36 ok · 0 FAIL · 0 个真 `--- SKIP`**（比 §28 的 35 多 1 个 = 新增 `internal/biz/appcfg` 测试包） |
| `gofmt -l`（本批 8 个 `.go` 改动文件） | 仅 `deploy/config/config.go`，已证明**在 HEAD 就不洁**（BOM + 字段对齐），归 #45 |
| `flutter analyze` | **0 error · 0 warning** · 38 info（既有 deprecation，rc=1 是 info 造成的，见 §0） |
| `flutter test` | **rc=0 · 98 passed** |
| 乱码检测器复跑 | **0 行** |
| 一次性产物 | 两份探针配置、`/tmp/moe-probe`、变异脚本与 `.bak` 全部删除，未入库 |

### 29.7 本批对方法论的追加

| # | 教训 |
|---|---|
| xxxi | **`make <目标>` 不等于「构建」**：先读 Makefile 再跑。本批把 `make moe-social`（实为 `go run`，一条永不返回的启动命令）当构建目标，导致一个连着共享测试库的进程无人看管地跑了 21 分钟。判据：跑完 `ls -la` 看产物时间戳有没有变 —— 本批正是靠「二进制还是 6 月 29 日的」+「`make` 0.0% CPU 且没有 `go build` 子进程」认出它卡住的，再 `pgrep -P` 才看到真正的子孙是 `exe/moe-social` |
| xxxii | **恢复被损坏的文本时，先在仓里找它自己的干净同胞**：同一条消息在 HEAD 上往往既有乱码副本也有干净副本，逐字节比对恢复结果与干净副本，比「检测器归零」强一个量级 —— 后者只证明「不再像乱码」，前者证明「与作者原意逐字节相同」 |
| xxxiii | **判定「重复代码该不该合并」要看兜底值，不只看函数体**：第四份 `normalizeBaseURL` 的规范化逻辑与 `TrimURL` 等价，但兜底是硬编码 `localhost` 而非另一个配置键 —— 合并它会静默改变线上图片地址。函数体相同 ≠ 语义相同 |
| xxxiv | **双向不变量要分别钉**：「注册表 ⊆ 档位放行」与「档位放行 ⊆ 注册表」是两个独立命题，既有用例只覆盖了前者，于是后者的分叉隐形了四批。对「任意字符串谓词」这类无法枚举输出的函数，反向那一半只能靠**显式探测历史上真分叉过的名字**，并前置断言这些名字仍不在注册表里 |
| xxxv | **检测器的判据要从成因推，不要从表象推**：乱码的成因是「UTF-8 字节被当 GBK 解」，所以判据是「恢复结果应当**变回中文**」，而不是「往返能否成功」。v2 只问后者，于是在 `统一` → `ͳһ` 这种短串上必然误报 |

### 29.8 本批未做 / 遗留

- **#16（gradle 签名口令 `?: "moe123456"` 兜底，`android/app/build.gradle.kts:27,29`）仍未做**，是 #43 原登记四项里唯一剩下的。两个卡点：① 必须做成**惰性**失败 —— `signingConfigs` 在配置阶段对所有构建求值，直接 `throw` 会连 `flutter run` 一起打死；② **本机无 gradlew / gradle，无法验证**，改了等于交一份没跑过的代码。需要先决定用什么方式验证（装 gradle / 交给 CI）。
- **第四份 `normalizeBaseURL` 的兜底分歧**（`localhost:8888` vs `api.public_base_url`）留给 #44，已写进 `TrimURL` 注释防止被误当遗漏。
- **`docs/dev/local-llm-tools.md` 整篇是死文档**，本批只在 `Moe-Intelligence-Stack-v1.md` §4 里注明了它为假，**没有删它**（删文档需要需求方确认，且 `docs/dev/memory-system-dashboard.html:354` 等处仍在引用同一批工具名）。
- **BOM / CRLF 四个文件**（含被 gitignore 漏掉的构建产物 `moe-admin/build-out.txt`）留给 #45 / #46。
- **本机磁盘仍然吃紧**：本批开始时 `/System/Volumes/Data` 为 181 GB / 228 GB（95%，剩 10 GiB）。§28.7 已披露过同一问题，本批未再清理（`go clean -cache` 释放的 7.1 GB 已被这轮冷构建重新吃掉）。**`make moe-social` 那次冷构建耗时超过 10 分钟，与缓存被清 + 磁盘吃紧都有关**。

---

## §30 2026-09-17 第十七批（#16/#44/#45/#46/#50/#51/#52）：七项遗留修复的逐项验收

本批只做收口登记，不重述实现过程。**验收判据是「跑过并看到」，不是「代码看起来对」**；
凡未跑到的，一律标为阻塞并写明卡在哪，不折算成通过。

> ⚠️ **本批不构成「全工程无 bug」的结论。** 它只证明这七项登记缺陷各自的判据成立。
> #47 仍是未修的 P0；下面 30.3 列的每一项都是活着的限制。

### 30.1 逐项验收

| 项 | 分类 | 实测证据 | **没有通过**的验收 |
|---|---|---|---|
| **#45** 格式门禁 | ✅ 已修复且验证 | 124 文件纯 gofmt（无语义改动）；`make check` 加入只检查不修改的格式门禁 + `CGO_ENABLED=1 go vet ./...`；`make check` **rc=0 · 0 FAIL** | — |
| **#52** 可复现生成 | ✅ 已修复且验证（一项判据换了形式，见下） | 工具链版本集中固定并在生成前逐个核对；连续两次生成 **79 个产物字节一致**（含 arena/pet 六份首次入库）；15 个负向场景（缺工具 / 版本错 / 陈旧产物）全部正确失败且**不写工作区**；`make check-gen` 只读通过；静态路由计数包已删、全仓零引用；README 与 `make help` 旧说明已清 | 计划要求「运行时路由枚举」。实际改用**静态判据**：`RegisterArenaHTTPServer` / `RegisterPetHTTPServer` 在 `internal/` 下**零调用方**，生成物不可能引入重复注册。这直接证明了计划真正关心的那件事，但**没有**逐条证明「服务实际暴露的路由集合未变」 |
| **#44** Agora 归并 + 公共地址派生 | ⚠️ 已修改，验证部分阻塞 | typed `agora.app_id/app_certificate` 入 `pkg/conf`（`config.go:49,73`）；5 处重复且相同的覆盖值清空并**保留 YAML 叶子键**（`feishu.redirect_uri` / `wechat.redirect_uri` / `app_client.public_base_url` / `image.public_base_url` / OSS CDN `public_base_url`），单点收敛到 `api.public_base_url`；`derive.go` 的 `PublicBaseURL` / `ImagePublicBaseURL` / `FeishuRedirectURI` / `WechatRedirectURI` / `TrimURL` 齐备；`make check` **rc=0** | `make test-race` 未跑（磁盘不足）；「实测公共配置 / 媒体 URL」需启动服务，而普通启动会写共享测试库，**未执行** |
| **#51** 消除假成功 | ✅ 已修复且验证（UI 部分受阻） | 未实现的创建走 Kratos 错误编码 → **真实 HTTP 501 + 外层 `success:false`**，经生产注册与编码器实测；Dart 侧 5 个 HTTP 回归通过；`chat_page.dart:836` 改用 `AiAgent.copyWith` 保留 `createdByUserId`/`isPublic`/`authorName` 元数据 | tavern 聊天页 / 编辑页被 `showGameFeatures=false` 门禁挡住，**「卡片保存失败」「保存成功但同步失败」的界面提示与 loading 恢复未在运行中的 UI 里确认** |
| **#16** 签名口令 | ⚠️ 已修改，**验证完全阻塞** | 两处明文兜底已删，只剩 `System.getenv(...)?.takeIf { it.isNotBlank() }`（`build.gradle.kts:27,29`）；守卫是**惰性**的——`validateReleaseSigningCredentials` 只被 `validateSigningRelease` / `packageRelease` / `signReleaseBundle` 通过 `dependsOn` 触发（`:66-80`），配置阶段不抛，故不影响 debug | 本机缺 Gradle Kotlin DSL 5.2.0 缓存，计划要求的三项检查（无口令 debug 可构建 / 无口令 release 明确失败 / 有效配置 release 签名）**一项都没进入 app 配置阶段**。不擅自下载大依赖。**这段代码没有经过任何一次 Gradle 执行** |
| **#46** 部署与仓库清理 | ✅ 已修复且验证（nginx 运行验证缺失） | 四处 `proxy_set_header Host` 统一用 `$moe_api_host`（`nginx-lan.conf:33,43,53,62`），Host 值不变、未换成 `$proxy_host`；6633/11434 登记为**外部推理依赖**（`devports/ports.go:21-26` + `ports.md:33-37`，明确「配置有读者、本仓库不提供监听」）；一次性切模型脚本已删；`moe_social_backend/` 保留并 gitignore（`.gitignore:164`） | 本机无 nginx：`nginx -t` 与实际代理请求的 Host / path / Authorization / WebSocket 行为**均未实测**，静态检查不等同运行验证。另：§29.8 延期过来的 `moe-admin/build-out.txt` 取消跟踪**未做**（见 §30.3 第 10 条） |
| **#50** OAuth 回跳与登录绑定 | ✅ 已修复且验证（真实供应商与浏览器链路除外） | **服务端**：`internal/oauthflow`（事务存储 + S256 challenge + 回跳白名单 + 一次性 ticket）；本批以 `-count=1` 复跑 `internal/oauthflow` / `internal/biz/user` / `internal/server` 三包 **rc=0 · 0 FAIL**，覆盖成功链路 ×3、取消、恶意回跳、缺失/篡改/过期/跨供应商 state、错误 verifier/flow、重放、并发至多成功一次、重启失效、拒绝 code-only。**客户端**：`flutter test` **144 passed**、`flutter analyze` **0 error · 0 warning**（39 info 均为既有 deprecation）。**跨语言接缝**：Dart 与 Go 共用 RFC 7636 附录 B 向量，本批另用 `openssl` 独立复算确认 `dBjftJeZ…` → `E9Melhoa2…`。**文档**：两份飞书文档已同步新协议，负向冒烟 a~f 每条都对应一个具名用例 | ① **浏览器「刷新后完成链路与失败提示」未验证**——磁盘不足以完成 web 构建，且需启动会写共享测试库的后端，还需真实飞书授权；② **原生 WebView / 微信 SDK 真机未验证**；③ **真实供应商授权未验证**。三者都是计划里单列的设备与人工依赖，**不以单测冒充** |
| **#17** config.yaml 去跟踪 | ⛔ 不在范围 | 用户明确取消（多机器开发需来回切换） | — |
| **#47** reset-password 越权 | ⛔ 不在范围（用户暂缓） | 本批**未触碰** `auth_flow_service.dart` 的三个 reset 方法，已逐个确认原样 | **仍是活的 P0 安全风险**，见 30.3 |

### 30.2 对前批记录的纠正

| 位置 | 原记录 | 纠正 |
|---|---|---|
| §29.6 | `flutter test` **98 passed** | 是当时的值，不是当前值。本批为 **144 passed**（OAuth 客户端新增 41 例 + 前批增量）。§29.6 作为历史快照**不改写**，读它时要知道它已过期 |
| §29.6 | `make check` **36 ok** | 同样是当时值。本批实测 **37 ok · 0 FAIL · 0 真 SKIP**，差的那 1 个是 #50 新增的 `internal/oauthflow` 包（`git ls-tree HEAD` 确认不在 HEAD 上）。**包计数会随新增测试包继续变，不要把它当固定基线读** |
| §29.8 | 「BOM / CRLF 四个文件（含被 gitignore 漏掉的构建产物 `moe-admin/build-out.txt`）留给 #45 / #46」 | **这个延期项没有落地。** 实测：`git ls-files --error-unmatch moe-admin/build-out.txt` 成功（**仍被跟踪**）、`git check-ignore` **rc=1**、`.gitignore` 里没有它；文件首字节仍是 **BOM**，内容仍有 GBK 乱码（`鉁?` = `✓` 被当 GBK 解）。成因：#45 的门禁是 `gofmt`，只管 `.go`，管不到 `.txt`；#46 的批准范围点名了 nginx / ports / 一次性脚本 / `moe_social_backend/`，**没有点名这个文件**，且计划明写「其他纯风格重组不计入本次必做项」。**未擅自删除跟踪文件**（那是需要确认的动作），见 §30.3 第 10 条 |
| §29.8 | 「#16 仍未做，是 #43 原登记四项里唯一剩下的」 | 本批已改代码，但**验证完全阻塞**；不能读成「#16 已完成」 |
| 第九批迁移清单（`utils/feishu_oauth_redirect.go` / `utils/wechat_oauth_redirect.go` 各 1 处 `AppReturnURL`） | 记为已迁移到 `pkg/conf` | 这两个文件已随 #50 **整体删除**（回跳地址改由 `oauth.allowed_return_urls` 白名单裁定，`AppReturnURL` 配置键不复存在）。当时的迁移是真的，只是产物后来没了 |
| §26.5 漏洞证据表（`state=https://evil.example/steal` → `?feishu_code=CODE-ABC`） | 实测 302 到攻击者站并带走授权码 | **保留原文，不改写**——那是 #50 修复前的真实实测记录，是这次修复的依据。只加注：见 §30.4 |

### 30.3 必须保留的限制（不因本批通过而消失）

1. **#47 是活的 P0**：`/api/user/reset-password` 无认证且不校验验证码即可改任意账号密码。用户明确暂缓，本批未动。**在修掉之前，任何「登录相关安全已收口」的说法都是错的。**
2. **Ollama 模型创建仍未实现**。#51 关闭的是「假成功」这个缺陷——现在它如实返回 501 与 `success:false`。**不要读成「模型管理功能已完成」。**
3. **Web OAuth 目前开箱不可用**：`oauth.allowed_return_urls` 默认只登记了 `moesocial://feishu/oauth` 与 `moesocial://wechat/oauth` 两个 App 深链。要在浏览器里跑通，**运维必须先把实际页面地址加进这份白名单**。这是批准设计（不自动信任 API origin / 任意 localhost / 局域网 / 隧道域名）的直接后果，不是 bug；服务端错误文案已可操作。
4. **微信原生 SDK 的 state 字符集待真机确认**：服务端 state 是 base64url（含 `-` / `_`），微信文档写的是 `a-zA-Z0-9`。若微信侧拒绝或改写该字符集，失败模式是 **fail-closed**（state 不一致 → 拒绝登录 + 明确文案），**不构成安全漏洞**，但会让微信原生登录不可用。
5. **前后端必须一起发布**：旧的 `code`-only 通路已在两侧同时关闭，旧客户端授权会明确失败而非静默降级。
6. **授权事务在进程内存**（无 DB / Redis）：**后端重启即全部失效**，用户需重新发起授权。与当前单进程架构一致，横向扩容前必须换成共享存储。
7. **热加载不是全链的**：#44 归并后，哪些配置改完即生效、哪些需重启，未逐项实测，不能承诺全链热加载。
8. **#16 的签名守卫从未被执行过一次**。它可能在第一次真实 release 构建时才暴露问题。
9. **`docs/dev/local-llm-tools.md` 整篇仍是死文档**（§29.8 已登记，本批未删）。
10. **`moe-admin/build-out.txt` 仍是被 git 跟踪的构建产物**（1324 字节，2026-08-03 一次 `npm run build` 的日志，提交于 `da55da53`）。它带 BOM、内容含 GBK 乱码，`.gitignore` 里没有它。§29.8 把它延期给 #45/#46，**两批都没覆盖到**：#45 的门禁是 `gofmt`（只管 `.go`），#46 的批准范围没点名它。本批也没动 —— **取消跟踪一个文件属于需要确认的动作**，不擅自做。推荐处置（待决定）：`git rm --cached moe-admin/build-out.txt` + 往 `.gitignore` 加 `moe-admin/build-out.txt`（或 `moe-admin/*.log`），文件本身留在磁盘上。

### 30.4 §26.5 漏洞的处置结果（加注，不改写原证据）

§26.5 登记的开放重定向 + 授权码外泄 + 无 CSRF 防护，已由 **#50** 修复，机制与原记录的「给 `isAllowedReturnURL` 加 host 白名单」设想**不同**，实际做法更严：

| §26.5 的成因 | #50 的处置 |
|---|---|
| 调用方传入的 `state` 被原样当回跳地址 | `state` 字段**完全忽略**（编号保留以免破坏 wire 兼容）；回跳地址改由独立的 `return_url` 提供 |
| `isAllowedReturnURL` 只校验 scheme，不看 host | 换成 `oauth.allowed_return_urls` **精确命中**（scheme/host/port/path 全比对），并拒绝用户信息段、非预期 query/fragment 与危险协议 |
| 302 把真实授权码挂到查询串上 | 服务端**原子消费 state**，把 code 封存进一次性 ticket；302 **只带 `oauth_ticket` + `oauth_state`**，授权码从不出进程 |
| 拿到 code 就能登录（账号接管） | 登录须出示 `ticket` + `code_verifier`，服务端核验 `S256(verifier) == challenge`；`code` 字段非空即拒 |
| 整条流程无 CSRF 防护 | state 由服务端生成（32 字节 base64url，不可预测），客户端只处理与本次发起配对的事务；陌生深链 / 无事务的 URL 一律拒绝 |

原表里那两行 `?feishu_code=CODE-ABC` / `?wechat_code=CODE-ABC` 现在由 `internal/oauthflow/store_test.go:154` 的
`TestAppendTicketQueryCarriesNoCode` 反向钉住：回跳查询串里出现 `code=` / `feishu_code` / `wechat_code` / `access_token` / `verifier` 任一即测试失败。

### 30.5 本批门禁复跑（收口时的权威数字）

| 门禁 | 实测 |
|---|---|
| `make check-format`（只检查不修改） | **rc=0** |
| `make check`（格式 + vet + 编译生产入口 + 全仓单测） | **rc=0 · 37 ok · 0 FAIL · 0 个真 `--- SKIP`** |
| 包计数差 | 比 §29.6 的 **36 ok 多 1 个** = 新增 `internal/oauthflow`（#50 引入，`git ls-tree HEAD` 确认不在 HEAD 上） |
| OAuth 三包单独复跑（`-count=1`） | `internal/oauthflow` **ok** · `internal/biz/user` **ok** · `internal/server` **ok**，rc=0 |
| `flutter analyze` | **0 error · 0 warning** · 39 info（均为既有 deprecation，含 `dart:html`，与既有 `oauth_web_history_web.dart` 同口径） |
| `flutter test` | **rc=0 · 144 passed**（§29.6 记的 98 已过期，见 §30.2） |
| 磁盘区间 | 本批 `/System/Volumes/Data` 可用 **524 Mi → 328 Mi → 1.1 Gi**（系统回收 purgeable 空间后回升） |
| 一次性产物 | `/tmp/oauth_test_run.log`、`/tmp/makecheck_final.log` 为本次日志，未入库 |

> 本批收口阶段只改了三份 `.md`（两份飞书文档 + 本文档），`make check` 不读 markdown；
> 上表是**改完之后**重新跑出来的，不是沿用早先的结果。

### 30.6 环境阻塞（本批实测）

`/System/Volumes/Data` 在本批从 **524 Mi 掉到 328 Mi**（100% 已用）。直接后果：

- 第一次跑 OAuth 三包测试出现一次**无诊断信息的 FAIL**，两次复跑（含 `-count=1`）均 **rc=0 · 0 FAIL**。磁盘在同一区间掉了近 200 Mi，**ENOSPC 打断编译是最可能的成因**，但未能确证 —— 如实记为「一次未复现的失败」，不记为通过也不记为缺陷。
- `make test-race`（#44）、Flutter web 构建（#50 浏览器验收）、Gradle 依赖解析（#16）均因空间不足无法执行。
- 按既定约束：**不清理全局缓存、不下载大型依赖、不删 TMPDIR 里属他人工具的 19 G `cursor-sandbox-cache`**。因此上述阻塞在本批内无解，只能登记。

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
- [飞书通知与绑定.md](./飞书通知与绑定.md) — 飞书配置 / OAuth 接口 / 代码索引（✅ §30 已同步新协议：`return_url` + PKCE + 一次性 ticket）
- [飞书OAuth授权验证指南.md](./飞书OAuth授权验证指南.md) — OAuth 联调与验收步骤（✅ §30 已同步；含不需要真实账号的负向冒烟 a~f）
