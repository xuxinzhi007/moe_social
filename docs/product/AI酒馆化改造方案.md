# Moe Social AI 酒馆化改造方案

> **文档索引**：[docs/README.md](../README.md) · **记忆（账号级）**：[用户记忆系统-OpenClaw式演进设计.md](../dev/用户记忆系统-OpenClaw式演进设计.md)（与 Lorebook 分工见该文）

日期：2026-05-18

## 0. 当前落地进度

截至 2026-05-18，当前实际进度：

- Phase 1 已落地：
  - Provider Profile
  - OpenAI-compatible / 中转站接入
  - 角色基础字段
  - 统一 Chat Gateway
- Phase 3 基础版已提前落地一部分：
  - Lorebook 实体
  - Lorebook 条目管理
  - Agent 绑定 Lorebook
  - 聊天时按关键词 / 常驻项自动注入世界书
- Phase 2 已落地一部分：
  - 角色卡 JSON 导出
  - 从粘贴内容导入角色卡
  - 导入时可带入 Provider 配置骨架与 Lorebook
  - 默认角色模板
  - 默认世界书模板
- 列表层已开始 Provider 化：
  - 模型广场支持切换 Provider 来源
  - 我的智能体列表展示当前 Provider / 来源标签
  - 不再把模型来源文案写死为 Ollama
  - AI 首页开始改造成更偏“酒馆入口”的产品页
- Provider 兼容层已补回退：
  - 对不允许 `system` message 的 OpenAI-compatible / 中转站接口，自动切换为非 `system` 注入重试
- 已开始补 Provider 能力画像：
  - 支持 / 不支持 `system`
  - 支持 / 不支持流式
  - 支持 / 不支持图像输入
  - 支持 / 不支持工具调用
- 已开始补后端化配置存储：
  - Provider 元数据后端优先
  - 用户 Persona 后端优先
  - 上次选择的 Provider 后端优先
  - Agent 后端优先
  - Lorebook 后端优先
- 已开始从“大配置接口”拆分为资源接口：
  - `/api/ai/providers`
  - `/api/ai/agents`
  - `/api/ai/lorebooks`
- 架构已回正为：
  - `API -> RPC -> DB`
  - AI 资源与 AI 用户配置由 RPC 层负责读写数据库
  - API 层仅做鉴权、参数适配与 RPC 转发
- 已完成 RPC 代码同步：
  - `super.proto` 已补 AI 资源与 AI 用户配置接口
  - `pb/super` 已重新生成
  - API 已切到 RPC 调用链路
- 已完成编译验证：
  - `backend` 当前可通过编译

下一步建议按优先级继续：

1. User Persona
2. 会话侧边栏与分支会话
3. 多角色群聊
4. 兼容 SillyTavern / TavernAI 风格角色卡格式

## 1. 目标

把当前 `AI 智能体` 页面从“模型聊天入口”升级为“高自由度角色聊天模块”。

目标形态参考：

- SillyTavern 的能力模型
- TavernAI 的角色卡思路

但本项目不直接照搬其实现，而是结合现有 Flutter + Go + 本地存储结构，逐步演进。

---

## 2. 产品定位

本模块定位为：

**高自由度 AI 角色聊天 / 陪伴模块**

它不是通用问答页，也不是单纯模型调试页，而是面向以下场景：

- 角色扮演聊天
- 陪伴式聊天
- 用户自定义人格 / 世界观 / 开场白
- 多模型切换
- 用户自带中转站 API 接入

---

## 3. 可参考的开源项目

可明确参考的对象：

- SillyTavern
- TavernAI

重点参考这些能力边界：

- Character Card
- Provider / API Connections
- World Info / Lorebook
- User Persona
- Group Chat
- Preset / Prompt Settings

不建议直接照搬：

- 整体前端结构
- 配置文件组织方式
- 插件系统
- 桌面优先 UI

原因：

- 本项目是 Flutter 移动端优先
- 当前已有本地 SQLite、Agent、本地记忆体系
- 社交产品属性强于纯 AI 前端工具

---

## 4. 当前基础

现有项目已经具备这些可复用基础：

- `AiAgent`：智能体基础模型
- `AiChatSession`：会话
- `AiChatMessage`：消息
- `AiDbService`：本地 SQLite 存储
- `ChatPage`：单智能体对话页
- `AgentEditorPage`：智能体编辑页
- `MemoryService`：长期记忆与画像能力
- 后端 `/api/llm/chat`：服务端 Ollama 聊天链路
- 后端 `/api/llm/*/raw`：原样调试链路

当前短板：

- 第三方 Provider 仍有部分聊天链路保留客户端直连，尚未完全统一到后端代理
- User Persona 已开始落地，但整体体验和联动还不完整
- 会话仍缺少分支与更强的侧边栏管理
- 角色卡导入导出仍是项目内 JSON 格式为主，尚未完整兼容酒馆生态格式
- 还没有多角色群聊
- Provider 能力画像还未完整产品化
  - 例如：是否支持 `system`
  - 是否支持多模态
  - 是否支持工具调用 / 特殊参数

---

## 5. 总体演进路线

## Phase 1：Provider 与角色基础层

目标：

- 支持本地配置中转站 / OpenAI 兼容 API
- 智能体增加角色卡基础字段
- 聊天发送链路改为可切换 Provider

交付物：

- Provider Profile
- 智能体角色字段
- OpenAI-compatible Chat Gateway
- Provider 管理页

## Phase 2：酒馆核心体验层

目标：

- 把“智能体”升级为真正的“角色卡”
- 强化沉浸式聊天体验

交付物：

- 开场白
- 示例对话
- 用户 Persona
- 会话侧边栏优化
- 角色卡导入导出
- 默认角色模板
- 默认世界书模板入口
- 更像“角色酒馆”的首页编排

## Phase 3：世界书 / Lorebook

目标：

- 支持场景设定、世界观、规则库注入

交付物：

- Lorebook 实体
- 关键词触发注入
- 会话绑定世界书

## Phase 4：高级酒馆能力

目标：

- 更接近 SillyTavern 的高阶玩法

交付物：

- 分支会话
- 多角色群聊
- 预设参数面板
- 图像/TTS扩展位

---

## 6. Phase 1 需求定义

## 6.1 Provider Profile

新增“AI 提供商配置”概念。

每个配置包含：

- 名称
- 类型
- Base URL
- API Key
- 默认模型
- 手动模型列表
- 是否启用服务端记忆

第一阶段只支持两类：

1. `backend_ollama`
2. `openai_compatible`

说明：

- `backend_ollama` 继续走现有后端链路
- `openai_compatible` 直接调用用户配置的兼容接口

## 6.2 智能体角色字段

在现有 `AiAgent` 基础上新增：

- `providerProfileId`
- `persona`
- `scenario`
- `openingMessage`
- `exampleDialogues`

这些字段用于拼接角色卡提示词，而不是完全替代 `systemPrompt`。

## 6.3 提示词构造逻辑

最终发送给模型的系统提示词由以下部分拼接：

- systemPrompt
- persona
- scenario
- exampleDialogues
- 固定行为约束

开场白不直接进入 system prompt，而是在新建会话时作为第一条 assistant 消息插入。

## 6.4 聊天网关

新增统一聊天网关：

- 根据 `providerProfileId` 选择链路
- `backend_ollama`：走当前后端 `/api/llm/chat`
- `openai_compatible`：走 `POST {baseUrl}/chat/completions`

模型列表能力：

- `backend_ollama`：继续从现有 `/api/llm/models` 获取
- `openai_compatible`：尝试请求 `GET {baseUrl}/models`
- 若失败，回退到用户手动输入的模型列表

兼容补充：

- 某些中转站 / 兼容网关不接受 `system` 角色消息。
- 当前实现已增加自动回退：
  - 先按标准 Chat Completions 发送
  - 若返回类似 `System messages are not allowed`
  - 则把 system prompt 折叠进首条对话上下文，再自动重试一次
- 这属于兼容兜底，不是最终最优方案。
- 后续建议在 Provider Profile 中显式记录能力，再由网关按能力选择注入策略。

## 6.5 配置存储

- 服务端结构化配置：`API -> RPC -> DB`
- 本地缓存与离线数据：SQLite
- API Key：安全存储
- Web 环境：允许降级为本地偏好存储

补充说明：

- 当前 `AiDbService` 不是后端数据库，而是客户端本地数据库。
- AI 的结构化配置已经开始进入后端数据库，由 RPC 层统一读写。
- 在移动端 / 桌面端，仍保留本地 SQLite 作为缓存与离线兜底。
- 在 Web 环境，部分数据会降级到浏览器本地存储或 Web 兼容存储。

当前本地存储的内容包括：

- 智能体元数据
- Provider 配置元数据
- 会话与消息
- Lorebook / 世界书
- 本地记忆相关表
- 用户 Persona 偏好
- 上次选择的 Provider

不放在本地数据库里的内容：

- 第三方 Provider 的真实远程模型数据
- 后端 Ollama 的实际模型权重
- 服务端业务数据库中的用户主数据

当前采取的混合策略：

- Provider 元数据：后端优先，本地兜底
- 用户 Persona：后端优先，本地兜底
- 上次选择的 Provider：后端优先，本地兜底
- Agent：后端优先，本地兜底
- Lorebook：后端优先，本地兜底
- 第三方 API Key：仍仅保留本地，不上传后端

当前接口分层：

- 资源接口：
  - Provider / Agent / Lorebook
- 配置接口：
  - User Persona
  - Preferences
  - 旧版大配置读取兼容

体量判断：

- Provider、角色卡、Lorebook 这类元数据体量很小，通常不会成为包袱。
- 真正可能增长较快的是“聊天消息历史”和“本地记忆”。
- 现阶段可接受；后续若聊天量继续上升，再补“历史清理 / 归档 / 限额策略”即可。

---

## 7. 数据结构建议

## 7.1 AiProviderProfile

字段建议：

- `id`
- `name`
- `provider_type`
- `base_url`
- `default_model`
- `manual_models_json`
- `use_server_memory`
- `created_at`
- `updated_at`

## 7.2 AiAgent 扩展字段

- `provider_profile_id`
- `persona`
- `scenario`
- `opening_message`
- `example_dialogues`

---

## 8. 页面改造

## 8.1 智能体列表页

新增：

- “Provider 管理”入口
- 本地智能体优先显示
- 不再完全依赖后端模型列表生成智能体
- 记住上次选择的 Provider，不再每次回到内置 Ollama

## 8.2 智能体编辑页

新增：

- Provider 选择
- 人设
- 场景
- 开场白
- 示例对话

保留：

- 名称
- 描述
- 系统提示词
- 模型选择
- Provider 能力标记

## 8.3 Provider 管理页

提供：

- 新建 Provider
- 编辑 Provider
- 删除 Provider
- 测试模型列表
- Provider 能力画像配置

## 8.4 角色卡导入导出

当前已支持：

- 从智能体导出角色卡 JSON
- 从粘贴文本导入角色卡 JSON
- 导入时自动创建本地角色
- 若角色卡内包含自定义 Provider 骨架，则自动导入 Provider 元数据
- 若角色卡内包含 Lorebook，则自动导入世界书和条目

当前限制：

- 不导出 API Key
- 导入后的自定义 Provider 仍需用户手动补充 API Key
- 暂不兼容 SillyTavern / TavernAI 常见图片卡或第三方卡格式

## 8.5 ChatPage 侧边栏与 Persona

当前已开始补：

- 用户 Persona 偏好
- 会话侧边栏入口
- 从侧边栏直接切换会话 / 打开记忆库 / 编辑 Persona

这一步的目标是把聊天页从“单轮对话”推进到“酒馆式会话管理”。

---

## 9. 技术约束

## 9.1 当前阶段不做

第一阶段明确不做：

- 分支对话
- 多角色群聊
- 远程同步 Provider 配置
- 后端统一代管第三方 API Key
- 第三方角色卡生态格式兼容

## 9.2 安全边界

当前阶段采用“用户自带 Key，本地存储，本地直连”方案。

适用前提：

- 面向高级用户
- 以高自由度为优先
- 接受客户端本地管理自己的密钥

后续若要平台化运营，再把第三方 Provider 接入迁到后端网关统一代理。

---

## 10. 第一阶段开发顺序

1. 扩展本地数据模型
2. 新增 Provider 配置存储服务
3. 新增统一聊天网关
4. 改造 AgentEditor
5. 改造 ChatPage / ContentGenerationPage
6. 新增 Provider 管理页
7. 补 AgentList 入口与展示

---

## 11. 验收标准

完成后，用户应能做到：

1. 新建一个 OpenAI-compatible Provider
2. 填写中转站 Base URL 和 API Key
3. 在智能体中选择该 Provider
4. 填写人设、场景、开场白
5. 发起对话并成功返回内容
6. 新会话自动带上开场白
7. 不影响原有 Ollama 后端链路

---

## 12. 决策

本阶段采用：

- **先做 Provider + 角色卡基础层**
- **后做世界书与高级酒馆能力**

不建议现在直接冲完整 SillyTavern 复制版。

原因：

- 当前项目已有自己的社交结构和移动端约束
- 先打通“可自由接模型 + 可自定义角色”的价值，收益最高
- 这样最容易尽快进入可用状态
