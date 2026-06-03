# P0 调整清单

日期：2026-06-03

## 结论

当前 P0 不是继续扩功能，而是先把产品主线、AI 核心体验和工程验证能力收住。充值页保持模拟，不纳入本轮 P0。

## 2026-06-03 本轮完成

- P0-0：`flutter test --no-pub` 已恢复全量通过；SQLite native asset 改为系统库 hook，相机权限测试改为 MethodChannel mock。
- P0-0：warning 级 analyzer 红灯已清零；当前可执行门禁为 `flutter analyze --no-fatal-infos`，剩余 251 条为 info 级旧债。
- P0-1：底栏主线收束为「首页 / 消息 / AI / 我的」；同好、社区保留为路由与首页入口，不再占底栏。
- P0-1：AutoGLM、raw 调试、本机 llama-server 等实验能力接入 `FeatureFlags`，默认不暴露给普通用户路径。
- P0-2：新增 `AiChatContextBuilder`，显式固定 Provider/Persona/Lorebook/Memory 的聊天上下文构建顺序；`chat_page.dart` 继续瘦身。

## P0-0 立即阻塞

| 项 | 证据 | 调整动作 | 验收 |
| --- | --- | --- | --- |
| Flutter 测试跑不起来 | `flutter test` 因缺 `third_party/sqlite3/sqlite3.c` 和权限插件未 mock 失败 | 已改 sqlite3 hook 为系统库；相机权限测试使用测试绑定与 MethodChannel mock | `flutter test --no-pub` 全量通过 |
| Analyzer 长期红灯 | 原有 281+ 条 warning/info | 已清 warning 级：protected `setState`、unused、dead/null 判断、未返回 handler；info 分批处理 | `flutter analyze --no-fatal-infos` 通过；剩余 info 进入 P1 基线 |

## P0-1 产品主线收束

| 项 | 证据 | 调整动作 | 验收 |
| --- | --- | --- | --- |
| 官网叙事与 App 底栏不一致 | 官网 mock 是「首页/消息/AI/我的」，App 原为「首页/同好/社区/探索/我的」 | App 底栏已改为「首页/消息/AI/我的」 | 新用户首屏能明确刷动态、聊天、AI、我的四个主动作 |
| 探索页职责过重 | 探索混合匹配、AI、小游戏 | 探索不再挂底栏；AI 提升为底栏主入口，同好/社区走路由入口 | 主路径 1 步进入 AI 或消息 |
| 实验功能默认暴露 | AutoGLM、demo、本地模型设置等偏开发者能力 | 新增 `FeatureFlags`，默认隐藏 AutoGLM、raw 调试、本机 llama-server | 普通用户路径不出现开发者工具入口 |

## P0-2 AI 核心体验闭环

| 项 | 证据 | 调整动作 | 验收 |
| --- | --- | --- | --- |
| AI 聊天页仍过长 | `chat_page.dart` 仍超长 | 已拆身份 Hero、会话抽屉、状态横幅、聊天上下文构建器；后续继续拆搜索/语音/持久化 | 发送/重试/停止行为不变；`flutter test --no-pub` 通过 |
| Provider 管理体验弱 | 产品文档标注 Provider 管理为 P0 重壳 | 底栏 AI 入口直接进入角色/Provider 管理；实验本地模型入口默认隐藏 | 新建角色路径更聚焦在角色与模型来源 |
| 角色卡 / 记忆注入链路仍需稳定 | 产品总览将聊天注入适配角色卡列为 P0 | `AiChatContextBuilder` 固定顺序：Lorebook 选择 -> Persona/SystemPrompt 组装 -> 非角色防自曝规则 -> Memory 注入 -> system message 入队 | 记忆注入结果继续回写页面状态，链路可解释 |

## P0-3 工程质量与分层

| 项 | 证据 | 调整动作 | 验收 |
| --- | --- | --- | --- |
| `api_service.dart` 过长 | 2280 行，跨多个业务域 | 按 auth/user/feed/chat/commerce 拆 domain service，保留 facade 过渡 | 新增 API 不再继续塞入总 service |
| 超长页面集中 | 多个页面超过 1000 行 | 先拆纯 UI，再拆状态/服务；每轮小 diff | 每次拆分后 `flutter analyze` 不新增 error |
| 硬编码线上地址 | `lib/utils/config.dart`、`lib/config/moe_api.json`、管理台 placeholder 含公网 IP | 明确配置 SSOT，App 默认从配置/环境读取，文档说明本地/线上切换 | 新克隆项目无需改源码即可切环境 |

## P0-4 安全上线前项

| 项 | 证据 | 调整动作 | 验收 |
| --- | --- | --- | --- |
| JWT 密钥轮换 | `security-and-stability-backlog.md` 列为上线前必须 | 生成新随机串并走环境变量 / secret 文件 | 生产不依赖仓库内旧密钥 |
| Android 签名默认密码 | backlog 指出 Gradle 有默认回退 | 删除默认密码，强制环境变量 | 无签名环境变量时 release 构建直接失败 |
| 生产配置入库风险 | backlog 指出 `config.yaml` 密钥风险 | 确认敏感配置只在服务器侧注入 | 仓库无生产 secret |

## 暂不列 P0

| 项 | 原因 |
| --- | --- |
| 充值真实支付 | 用户已明确保持模拟；页面文案已说明不会真实扣费 |
| 扭蛋 / 背包真实库存 | 属于商业化 P1；若准备公开内测，可先隐藏或标内测 |
| 多角色群聊 / 分支会话 | AI P2 能力，不影响当前核心单聊闭环 |
| 完整插件系统 | 产品总览已明确不建议现在做 |

## 建议执行顺序

1. 继续分批清理 251 条 analyzer info，优先 `use_build_context_synchronously` 与 `avoid_print`。
2. 继续拆 `chat_page.dart` 的搜索、语音、持久化 controller。
3. 拆 `api_service.dart`，按 auth/user/feed/chat/commerce 保留 facade 过渡。
4. 对首页、消息、AI、我的四主线补一轮手动冒烟。
5. 对 Provider、Persona、Memory、Lorebook 注入链路补单测或可观测日志。
