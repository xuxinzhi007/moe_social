# 前后端业务统一转型设计

## 背景

Moe Social 当前同时包含 Flutter App、Go/Kratos 后端、AI 伙伴、本地模型和小主机推理服务。随着功能增多，部分业务判断散落在 Flutter service、Provider、后端 biz/service 和 AI 接入代码中，容易出现以下问题：

- 前端和后端各维护一套业务规则，联调时难以判断谁是准的。
- Flutter 页面和 service 变重，编译、调试和运行时排错成本上升。
- AI 小主机地址、模型选择、会话上下文和记忆策略容易穿透到客户端。
- 构建或运行环境出问题时，业务问题、模型问题和客户端问题混在一起排查。

本方案的目标不是换掉 Flutter，而是把业务事实源统一收回后端，让 Flutter 回到 App 体验层。

核心结论：

- 继续使用 Flutter。问题不在 Flutter 语言本身，而在前端承担了太多业务判断。
- 后端作为业务事实源。权限、关系、模型路由、成长奖励、内容可见性等规则只在后端落地。
- Flutter 作为体验终端。页面、动画、输入、草稿、乐观 UI、错误提示和重试留在客户端。
- 小主机 Ollama 是推理运行时，不是产品后端。App 不直接依赖它的模型名、地址或协议。

## 方案

### 目标架构

```text
Flutter App
  - 页面展示
  - 输入、动画、导航
  - 加载/空态/错误/重试
  - 草稿、滚动位置、乐观 UI 等体验状态
        ↓
Go/Kratos Backend
  - 用户身份与权限
  - 社交关系、Feed、帖子、评论、通知
  - Companion 档案、记忆、主动陪伴、会话上下文
  - AI 网关、模型路由、失败处理、审计记录
        ↓
Model Runtime
  - 小主机 Ollama / 本地模型 / 外部模型
  - 只做推理，不承载 App 业务规则
```

正式调用链：

```text
Page / Widget
  -> ViewModel / Provider
  -> Domain Service
  -> Backend API
  -> service
  -> biz
  -> data / pkg / external runtime
```

客户端禁止跨过 `Domain Service` 直接把页面接到底层 HTTP；后端禁止绕过 `biz` 把业务判断写进 HTTP 适配层或 data 层。

### 分层边界

| 能力 | Flutter 保留 | 后端统一 |
|------|--------------|----------|
| 用户身份 | 保存 token、展示登录态 | JWT 校验、用户归属、权限判断 |
| Feed | 骨架屏、分页 UI、失败重试 | 排序、可见性、过滤、推荐结果 |
| 发帖/评论 | 表单、草稿、上传进度、乐观 UI | 发布规则、权限、数据写入、审核状态 |
| 好友/私信 | 会话展示、未读提示、断线提示 | 关系校验、消息持久化、未读计数、推送 |
| Companion | 聊天界面、输入体验、状态展示 | 伙伴身份、记忆、上下文、主动陪伴、模型路由 |
| 模型配置 | 展示当前可用能力和错误提示 | 供应商配置、模型名、连接策略、降级策略 |
| 本地模型 | 不直接绑定业务规则 | 通过后端 AI 网关调用 |
| 成长体系 | 签到按钮、等级展示、进度动效 | 经验来源、等级阈值、奖励发放、成就解锁 |
| 内容生成 | 输入表单、生成中状态、结果展示 | 类型策略、Prompt、角色上下文、模型调用 |

### Flutter 约束

- 页面只依赖 ViewModel 或领域 Service，不直接依赖 `ApiService` / `ApiClient`。
- Flutter Service 只做客户端适配：请求、响应转换、错误映射、缓存和重试提示。
- 不在 Flutter 中决定用户是否有权限、某条内容是否可见、AI 应该选哪个模型、记忆是否应该写入。
- 可以保留本地体验逻辑，例如输入草稿、滚动位置、乐观插入、临时失败提示。
- 新增配置时优先问：这是业务配置还是客户端体验配置。业务配置进后端，体验配置才进 Flutter。

### 后端约束

- 契约以 `backend/api/<domain>/v1/*.proto` 为事实源。
- HTTP 入口继续走 Kratos `protohttp -> service -> biz -> data`。
- service 层负责参数校验和 DTO 转换，biz 层负责业务规则，data 层负责 DB、缓存和外部 IO。
- AI 相关能力统一进入后端 AI 网关，不允许 Flutter 绕过后端直接决定模型业务策略。
- 小主机模型地址、模型名、超时和降级策略走后端配置，不写进页面或业务组件。

### AI 网关边界

AI 网关负责：

- 根据登录用户加载 Companion Profile。
- 根据会话加载必要记忆和上下文。
- 根据后端配置选择模型运行时。
- 记录请求、失败、耗时和必要审计信息。
- 把模型失败转换成客户端可展示的业务错误。

模型推理服务只负责：

- 接收 prompt / messages。
- 调用模型。
- 返回文本、流式片段或结构化结果。

模型推理服务不负责：

- 判断用户归属。
- 写入用户记忆。
- 决定 Companion 身份。
- 决定产品权限。
- 直接暴露给 Flutter 主路径。

### 接口设计原则

- 后端响应直接表达业务结果，不要求 Flutter 二次推断。例如返回 `can_comment`、`level_title`、`next_level_exp`、`retryable`，而不是让客户端用字符串或阈值自己算。
- 错误由后端映射为稳定状态和中文短文案。Flutter 只负责展示、重试和必要的乐观 UI 回滚。
- 新增字段优先可选，避免老客户端崩溃。删除字段必须等前端旧路径清干净后再做。
- 流式接口只传展示事件：`start`、`delta`、`done`、`error`。Prompt、记忆、模型选择不进入事件协议。
- 诊断接口和正式接口分开命名。`raw`、`debug`、`diagnostics` 只能用于开发排障，不进入正式页面主路径。

### 排障边界

以后遇到“编译起不来、运行闪退、AI 报错”按三段拆开，不混在一起修：

| 类别 | 首查 | 不应该归因到 |
|------|------|--------------|
| Flutter/Android 构建失败 | Gradle、Flutter SDK、Android 插件、设备日志 | 小主机模型 |
| App 运行崩溃 | Flutter runtime log、目标页面 Provider、动画 Ticker、内存峰值 | 后端业务规则 |
| 后端 API 报错 | 后端日志、HTTP 响应、biz/service 测试 | Flutter 页面布局 |
| 模型响应失败 | 后端 AI 网关、小主机 `/api/tags` 和 `/api/chat` | Flutter 是否拼 Prompt |

这样做的目的很直接：编译问题先保证 App 能启动；后端问题用 API 直接打通；模型问题只在后端到小主机之间定位。

## 影响范围

第一批重点域按优先级执行：

| 优先级 | 域 | Flutter 重点 | 后端重点 |
|--------|----|--------------|----------|
| P0 | 构建/启动稳定性 | Android 配置、启动日志、主路径崩溃点 | 不参与构建问题 |
| P0 | Companion / AI | `companion_service.dart`、AI 页面、流式展示 | `biz/companion`、`biz/llm`、`pkg/llminference` |
| P0 | Feed / 发帖 / 评论 | feed 页面、创建页、评论页 ViewModel | `biz/post`、`biz/comment`、错误映射 |
| P0 | 私信 | 会话页、乐观发送、断线提示 | `biz/chat`、WebSocket、未读与关系校验 |
| P1 | 成长体系 | `GrowthService`、签到/等级 Provider | checkin、level、achievement 规则 |
| P1 | 用户/关系 | profile、follow、friend UI | user/follow/friend biz |

暂不作为第一批：

- 管理台 `moe-admin/`
- 实验游戏、Arena、Battle 等隐藏或弱主路径功能
- 纯视觉组件和主题系统

## 迁移步骤

### 阶段 0：稳定构建与运行

- 保持 Android/Flutter 构建稳定配置。
- 本地模型、小主机和后端连通性单独排查，不和 Flutter 构建问题混在一起。
- 对开发地址、模型地址、后端地址做一次清点，确认哪些仍然在 Flutter 中承担业务含义。
- 避免用全量重构验证构建问题；优先跑目标文件 analyze、目标单测、后端小包测试。

验收：

- `flutter run` 能启动。
- 后端 `make moe-social` 能启动。
- App 访问后端失败时，错误能明确指向地址或后端运行状态。
- 小主机 Ollama 不可用时，App 仍能看到后端返回的明确错误，而不是客户端崩溃。

### 阶段 1：梳理前端业务判断

- 搜索 Flutter 中直接调用 `ApiService` / `ApiClient` 的页面和 Provider。
- 标记前端正在做的业务判断：权限、可见性、模型选择、记忆写入、默认角色选择。
- 把判断分类为“体验状态”或“业务事实源”。
- 每个条目都绑定一个后端 owner：`user`、`post`、`comment`、`chat`、`companion`、`llm`、`checkin`、`achievement`。

验收：

- 形成一张迁移清单。
- 每个条目都有目标后端域和 Flutter 保留职责。
- 新增 Flutter 代码不再扩大 `ApiService` 直接调用面。

### 阶段 2：收敛 Companion 与 AI

- Companion 聊天统一走后端契约。
- Flutter 不再直接拼模型 endpoint、模型名和上下文策略。
- 本地模型和小主机只作为后端 AI 网关的运行时。
- 保留 Flutter 的聊天输入、流式展示、失败提示和重试体验。
- 保留 raw/debug 接口用于开发排障，但正式页面不再调用 raw 模型协议。
- 普通 AI 聊天历史从本地 SQLite / SharedPreferences 迁到后端用户会话，不再让登录态之外的本机缓存成为事实源。

验收：

- App 只调用后端 Companion/LLM 契约。
- 断开小主机时，Flutter 看到的是后端返回的可展示错误。
- Companion 记忆和身份只以后端为准。
- 后端可用直接 HTTP/SSE 验证 Companion 调用，不依赖 Flutter 才能判断链路是否正常。
- 同一账号重新登录、换设备或重装后，普通 AI 聊天会话能从后端恢复。

### 阶段 2.5：普通 AI 聊天历史后端化

当前状态：

- 后端已经有 `ai_chat_sessions` 和 `ai_chat_messages` 表，并且管理台已有只读查询。
- App 普通 AI 聊天页仍以本地 `AiDbService` / Web `SharedPreferences` 为主保存会话和消息。
- 结果是：模型调用可以成功，但登录后、换设备后、清缓存后，用户看到的聊天历史可能像“丢了”。

目标状态：

- 后端成为普通 AI 聊天历史的唯一业务事实源。
- Flutter 保留本地临时草稿、滚动位置、发送中气泡和失败回滚，不再把本地会话库当最终历史。
- 管理台继续使用管理接口读取审计数据；App 使用用户自己的正式接口，不能复用 admin 路由。

建议新增 App 侧接口：

| 接口 | 职责 |
|------|------|
| `GET /api/llm/chat/sessions?agent_id=...` | 拉取当前用户某个角色的会话列表 |
| `GET /api/llm/chat/sessions/{session_id}/messages` | 拉取当前用户某个会话的消息 |
| `POST /api/llm/chat/sessions` | 创建或更新当前用户会话标题、角色、模型摘要 |
| `DELETE /api/llm/chat/sessions/{session_id}` | 删除当前用户自己的会话和消息 |
| `POST /api/llm/chat/messages` | 记录用户消息、助手消息或错误占位 |

服务端写入规则：

- `session_id` 由 App 生成也可以，但必须绑定 `user_id`，后端按 `user_id + session_id` 做归属校验。
- 写入用户消息和助手消息时允许幂等，优先使用 `source_msg_id` 防止重试重复落库。
- `/api/llm/chat` 成功返回助手内容后，后端应能记录助手消息；如果为了兼容先由 App 调 `POST /api/llm/chat/messages`，也必须由后端校验归属。
- 删除、读取、更新都不能跨用户。
- 模型名、agent_id、标题只作为会话元数据，不能由前端据此绕过后端模型路由规则。

Flutter 迁移顺序：

1. 新增 `AiChatHistoryService` 作为客户端适配层，页面不直接调底层 HTTP。
2. `chat_page.dart` 首屏优先加载后端会话；后端失败时展示可重试错误，不静默退回旧历史。
3. 发送消息时保持当前乐观气泡体验，同时把用户消息和助手回复写入后端。
4. 删除会话、重命名会话以后端结果为准；本地只同步展示状态。
5. `AiDbService` 中的聊天 `sessions/messages` 仅作为离线草稿或迁移读取来源，不能继续承担正式历史。

验收：

- 同一账号退出再登录后，普通 AI 聊天历史仍在。
- 换一台设备登录同一账号后，能看到后端历史。
- 删除会话后，刷新页面不会从本地缓存“复活”。
- 后端针对列表、消息读取、写入幂等和越权访问有小范围测试。
- Flutter 目标文件 analyze 通过，不跑不必要的全量构建。

### 阶段 3：收敛社交主路径

- Feed 排序、帖子可见性、评论权限、未读计数以后端为准。
- Flutter ViewModel 只维护列表展示状态、分页游标、乐观 UI 和错误提示。
- 对老接口保持兼容，新增字段优先可选，不破坏旧客户端。
- 发布、评论、私信等写操作以后端错误码为准，Flutter 不再用本地缓存阻断最终业务动作。

验收：

- 主路径页面无新增直接 `ApiService` 调用。
- 关键业务规则在后端 biz 层可测试。
- Flutter 失败文案不再解析后端原始错误字符串。

### 阶段 4：清理前端旧逻辑

- 删除已经迁到后端的前端重复判断。
- 旧 AI 本地直连路径如果仍需保留，只能作为开发诊断入口，并默认不进正式主路径。
- 更新相关文档和联调步骤。
- 对仍保留在 Flutter 的逻辑标注原因：体验状态、离线缓存、动画状态或输入草稿。

验收：

- Flutter 业务 Service 只做客户端适配。
- 后端拥有业务规则测试。
- 文档中的边界和代码实际一致。

### 阶段 5：固化质量门禁

- 后端业务规则必须有 biz/service/protohttp 小范围测试。
- Flutter 只对触及文件跑 analyze 和必要 widget/service 测试，避免每次全量压垮开发机。
- 文档同步更新 `CODE_WIKI.md` 和本文件的“已落地切片”。
- 重复踩坑只在确认后写入 `.cursor/LESSONS.md`。

验收：

- 新 PR/提交能说明“业务规则在哪里、客户端只保留什么”。
- 构建问题、后端问题、模型问题有独立验证命令。

## 回滚方案

- 每个域按接口增量迁移，不一次性替换全仓。
- 后端新增字段保持可选，旧 Flutter 客户端可以继续解析。
- 已迁移到后端的正式路径不保留 Flutter 业务 fallback；需要排障时使用后端诊断入口。
- AI 小主机调用失败时，回滚后端模型运行时配置即可，不需要发布 Flutter 新包。

## 禁止事项

- 不为了“转型”把 Flutter 换成 Kotlin/Swift。
- 不在 Flutter 页面里新增业务权限判断。
- 不让模型推理服务直接承担用户、记忆、权限和产品规则。
- 不新增一堆客户端开关掩盖边界问题。
- 不一次性重构所有页面；按主路径逐域收口。

## 下一步执行清单

1. 先把当前构建/运行闪退问题独立收口，保证 `flutter run` 主路径可启动。
2. 继续清点 Flutter 直接调用 `ApiService` / `ApiClient` 的页面和 Provider，按 P0/P1 排序。
3. Companion/AI 只保留后端正式契约，raw/debug 留给诊断入口。
4. Feed、评论、私信、成长体系逐域迁移，规则进入后端 biz，Flutter 删除重复判断。
5. 每迁一个域，同步补后端小范围测试、Flutter 目标 analyze 和文档“已落地切片”。

## 迁移判定表

遇到一段逻辑时按这张表判断放哪：

| 判断问题 | 放在 Flutter | 放在后端 |
|----------|--------------|----------|
| 没网络时是否展示重试按钮？ | 是 | 否 |
| 用户是否能发这条评论？ | 否 | 是 |
| 等级 4 到 5 需要多少经验？ | 否 | 是 |
| 发送消息失败后是否回滚乐观气泡？ | 是 | 否 |
| AI 应该使用哪个模型？ | 否 | 是 |
| 这一轮对话要带哪些记忆？ | 否 | 是 |
| 文本框草稿是否恢复？ | 是 | 否 |
| 某条帖子是否可见？ | 否 | 是 |
| 页面按钮是否禁用以防重复点击？ | 是 | 否 |
| 写操作最终是否允许？ | 否 | 是 |

## 已落地切片

### 2026-09-23：模型提示词读取后端化

- 新增后端结构化接口 `GET /api/llm/model-prompt?model=...`。
- 后端负责模型授权、调用推理运行时、解析模型元数据中的系统提示词。
- Flutter 角色编辑页不再调用 `/api/llm/show/raw`，也不再解析 Ollama `modelfile`。
- `/api/llm/show/raw` 暂时保留为调试/兼容入口，但不作为正式 App 路径。

### 2026-09-23：聊天上下文装配后端化

- `/api/llm/chat` 新增 `agent_id`，后端按登录用户读取服务端角色卡。
- 后端负责合成系统提示词、角色人设、场景、示例对话、用户 Persona 与世界书命中条目。
- 后端优先使用服务端角色卡上的 `model_name`，避免 Flutter 旧状态决定模型路由。
- Flutter 聊天页只发送可见聊天历史、会话 ID、消息 ID 和交互采样参数。
- 删除 Flutter 侧 `AiChatContextBuilder`、`AiRoleplayPromptBuilder`、`AiLorebookService`，避免提示词业务双维护。

### 2026-09-23：内容生成提示策略后端化

- `/api/content/generate` 从占位实现改为调用后端 LLM 网关。
- 后端统一维护 text/image/video/code/article/story/poem 七类内容生成策略。
- 内容生成可携带 `agent_id`，后端会把类型任务提示合并到服务端角色上下文。
- Flutter 内容生成页只提交类型、用户输入和当前 agent，不再拼 system prompt 或调用 `/api/llm/chat`。
- 移除 `example.com` 图片/视频假返回，LLM 未初始化时明确暴露后端服务不可用。

### 2026-09-23：群组发帖权限裁决后端化

- 发帖到兴趣小组时，后端 `postbiz.Create`/`LinkPostToGroupTx` 统一校验群组存在与成员关系。
- `protohttp/post` 将未入群、群不存在、内容为空等业务错误映射为稳定 HTTP/gRPC 状态与中文文案。
- Flutter 发帖页移除 `canPostToGroup` 预检、按钮禁用和本地阻断，只保留发布交互与后端错误提示。
- 避免客户端 `group.isJoined` 旧缓存决定是否能发帖，权限事实源以后端为准。

### 2026-09-23：评论关系与评论输入裁决后端化

- 评论列表以后端 `parent_id` 与 `reply_to_user_name` 为准。
- Flutter 评论页移除按 `@昵称` 推断父评论的兼容逻辑，不再从文本猜业务关系。
- 后端创建评论会 trim 内容并拒绝空评论，避免前端成为唯一校验点。
- `protohttp/comment` 将空评论、父评论不存在、父评论不属于当前帖子、未登录等错误映射为稳定状态与中文文案。

### 2026-09-23：私信输入与错误裁决后端化

- 私信发送、拉取会话、清理历史的参数与业务错误统一改为 `chatbiz` sentinel errors。
- `protohttp/chat` 将未登录、自己给自己发、空消息、图片参数、用户不存在等错误映射为稳定状态与中文文案。
- Flutter 私信页继续只负责输入、乐观插入、回滚和 toast 展示，不再需要根据后端原始错误字符串推断业务含义。

### 2026-09-23：Companion Ollama 调用闭环修复

- 小主机 Ollama `/api/tags`、流式 `/api/chat`、非流式 `/api/chat` 均已直接验证可用。
- 后端 Companion 流式调用失败后，非流式兜底不再继承已取消的上游 stream context，避免出现 `stream chat failed ... non-stream fallback failed: inference request canceled` 的误导性错误。
- 本地 Ollama 推理超时调整为 300 秒，适配 CPU 小主机长上下文首包较慢的情况。
- Flutter Companion 仍只消费后端 SSE 事件并展示交互，不直接拼接 Prompt 或绕过后端调用 Ollama。

### 2026-09-23：成长域前端适配层收口

- 新增 Flutter `GrowthService` 作为签到、等级、经验日志、每日浏览经验的客户端适配层。
- `CheckInProvider`、`UserLevelProvider`、`DailyGrowthService` 不再直接调用底层 `ApiService`。
- 移除 `UserLevelProvider.updateExperience` 中本地推算等级阈值的重复业务逻辑，等级结果以后端 `GetUserLevel` 为准。

### 2026-09-23：全局加载 Provider 去业务 API 化

- `LoadingProvider` 不再直接调用登录、注册和图片上传底层 API。
- 登录/注册统一转交 `AuthService`，确保 token 保存、在线状态、缓存清理等认证副作用只维护一处。
- 图片上传统一转交 `UserService.uploadImage`，Provider 只负责加载状态、成功/错误消息和回调编排。

### 2026-09-23：Companion 上下文构建降级

- Companion 聊天上下文中的关系事件属于增强上下文，读取失败时不再中断聊天主路径。
- `BuildContext` 会记录关系事件读取错误并降级为空事件列表，保留 Profile、State、记忆和聊天历史继续进入模型调用。
- `companion_relationship_events` 增加按 `user_id + created_at` 的查询索引声明，降低“取最近关系事件”在数据增长后拖慢聊天的风险。
- 模型回复后的助手消息保存、亲密度更新和完成事件记录使用独立短超时上下文，避免 SSE 请求结束后收尾写入被取消。

### 2026-09-23：AI/Companion 页面底层 API 收口

- `CompanionHubPage` 不再直接调用 `ApiClient.uploadImage*`，伙伴头像上传统一走 `CompanionService`。
- AI Provider 配置页不再直接读取 `ApiService.baseUrl`，内置后端展示统一走 `AiProviderService.backendBaseUrl`。
- `AiManagedModelsViewModel` 的账号切换检测改为读取 `AuthService.token`，不再依赖低层 `ApiClient.token`。
- `pages/widgets/providers` 中剩余的底层 HTTP 命中已收敛到领域服务调用；AutoGLM 保持实验 Flag 例外。

### 2026-09-23：成长页面业务展示去重

- 等级页移除前端写死的每日任务、社区排行、等级特权和经验来源卡片。
- `UserLevelProvider` 不再维护本地等级称号和等级特权表，页面只展示后端返回的等级、称号、进度和成就数据。
- 签到页移除前端自行推算的连签里程碑奖励和“更多活跃任务”预告，保留后端返回的今日奖励、明日奖励和等级进度。
- 成长域后续若要展示任务、里程碑、特权或经验来源，先扩展后端契约，再由 Flutter 负责排版和交互。

### 2026-09-23：Companion 记忆与聊天历史闭环

- 直接验证 `/api/companion/memories`、`/api/companion/chat/history` 和 `/api/companion/state` 可返回当前用户服务端数据，聊天记录已由后端持久化。
- Flutter `CompanionService` 兼容解析后端 proto JSON 中以字符串返回的 `uint64` ID，避免记忆、冲突、事件和聊天记录 ID 变成 0。
- 后端记忆注入将未确认记忆标为“待用户确认的印象”，允许模型在用户询问“你记得什么”时自然提起，但不能当成已确认事实。
- 记忆计入时机：Companion 成功完成一轮聊天后，后端异步从“用户消息 + 助手回复”中提取记忆；确认、置顶、编辑由用户在记忆页管理。

### 2026-09-23：普通 AI 聊天历史后端化第一阶段

- 新增用户侧 AI 聊天历史后端路由：会话列表、会话消息、创建/更新会话、删除会话、保存消息、删除单条消息。
- 后端复用 `ai_chat_sessions` / `ai_chat_messages` 表，并补充 `agent_id`、`title` 会话元数据，用于按角色恢复历史与显示会话标题。
- 后端历史写入按当前登录用户归属校验，消息保存按客户端 `message_id/source_msg_id` 幂等，避免重试重复落库。
- `/api/llm/chat` 收到 `session_id` 与 `source_msg_id` 时会自动保存用户消息与助手回复，前端保存调用只作为外部 Provider 和重试补偿。
- Flutter 新增 `AiChatHistoryService`，普通 AI 聊天页加载/创建/删除会话、加载/保存/删除消息均走后端历史服务；后端 Provider 的正常对话由后端落库，外部 Provider、开场白和错误气泡由前端通过历史服务补写。
- `ChatPage` 不再使用本地 `AiDbService` 或 Web `SharedPreferences` 作为普通 AI 聊天历史主路径；本地页面状态只保留输入、气泡、生成中、滚动和错误提示。
- 已验证：`flutter analyze lib/pages/ai/chat_page.dart lib/services/ai_chat_history_service.dart` 通过；`go test ./internal/service/llm ./internal/data/llm ./internal/server/protohttp/llm -count=1` 通过。
