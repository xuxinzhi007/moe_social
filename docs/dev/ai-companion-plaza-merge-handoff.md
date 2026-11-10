# 身份卡广场并入陪伴：交接上下文

> **日期**：2026-11-10  
> **状态**：方向已口头确认，代码未改  
> **先读**：本文，再读 `ai-companion-formal-decisions.md`。两文冲突时，以本文的「合并方向」为准；社交主路径、单活跃伙伴、世界只是延伸，仍以正式决策为准。  
> **不要先做**：群聊、双人卡、时光机、把 FLAI 的市场或付费层搬进来。

参考对象是本机 MT 里的 FLAI 2.0.8（`com.flai.flai`）。它的业务在 `libapp.so`，安装包里没有角色卡 JSON。可借鉴的是模块化身份卡和「广场挑选、聊天消费」的分工，不是它的多角色大厅。

---

## 1. 现在为什么别扭

同一份人设有两个落点，聊天只稳定吃到其中一个。

| 事实 | 位置 | 实际被谁读 |
|------|------|------------|
| 身份卡 | `lib/models/ai_agent.dart`，服务端 `agents_json` | 广场列表、编辑器 |
| 广场「使用」 | `lib/pages/ai/character_card_plaza_page.dart` 的 `_applyCard` | 把卡压成一段，经 `LlmApiService.upsertAgentPrompt` 写进托管模型的系统提示词 |
| 陪伴资料 | `CompanionProfile`：`persona`、`personality_traits`、`greeting_style`、`system_prompt_override`、`agent_id` | 资料读写。`agent_id` 已有字段 |
| 聊天拼装 | `backend/internal/biz/companion/llm.go` 的 `buildSystemPromptWithContext` | 见下一节 |
| 字数弹窗 | `lib/pages/companion/companion_chat_page.dart` 的 `_shownContextUsage` | 用本地名字、人设、性格估算，不是服务端拼装结果 |

广场入口还在。关系首页「身份卡」进 `/character-card-plaza`。这和旧决策里「酒馆大厅退役」不矛盾：退役的是多会话选角大厅，不是这张身份卡。

`_cardPrompt` 只取 `systemPrompt`，空了才拼接 `persona + scenario + exampleDialogues`。`openingMessage` 和 `lorebookId` 不会进入这段文字。

编辑伙伴（`companion_profile_edit_page.dart`）保存时：提示词改动写托管模型；返回给上一页的主要是名字和头像。文件导入能解析角色卡，但注释写明不做世界书全量导入，也不把卡落成酒馆 Agent。

---

## 2. 服务端这一轮真正送进模型的内容

`buildSystemPromptWithContext` 文件头注释写了会注入 `persona` 和 `system_prompt_override`。函数体没有写这两段。当前顺序是：

1. 托管模型的系统提示词（`modelSystem`）。广场套用的卡在这里。
2. 固定句：你是 AI 伙伴，名字是资料里的 `name`。
3. `[关系]`：只按 `relationship_level` 给一段阶段说明。
4. `[说话方式]` 和画图规则（`<draw>`）。
5. `[你记得的事]`：置顶或用户已确认的记忆。
6. `[待用户确认的印象]`。
7. `[最近的关系进展]`。

历史在 `buildMessagesWithContext`：最近 6 条，正文合计约 500 字（`companionHistoryMessages`、`companionHistoryRuneBudget`）。用户这句话前面另有一条只含时间的 system。场景不送进模型。

所以会出现：广场提示「已写入某模型」，关系首页人设也改了，下一句回复仍只像模型里的旧系统提示词。调试弹窗却按本地人设报字数。

---

## 3. 合并后的唯一链路

身份卡是作者格式。广场只负责发现、筛选、选用。陪伴聊天是唯一说话的运行时。

选用一张卡时只更新当前伙伴：

- `agent_id` 指向这张卡
- 名字、头像跟卡走
- 不调用 `upsertAgentPrompt` 把卡文案写进托管模型

托管模型只表示基座，不表示角色。

下一轮由陪伴拼装按卡重读模块。建议顺序和裁剪：

| 顺序 | 内容 | 裁剪 |
|------|------|------|
| 1 | 说话规则、关系阶段 | 不裁 |
| 2 | 卡前缀：`persona`、`scenario`、`exampleDialogues` | 超预算先砍示例对话 |
| 3 | 置顶记忆，然后已确认记忆 | 沿用现有记忆接口 |
| 4 | 卡的 `systemPrompt`，仅当作者另写了覆盖 | 放最后，避免盖住规则 |
| 5 | 最近对话 | 维持 6 条 / 约 500 字 |
| 6 | 用户这一句 | 不裁 |

`description` 只给广场和关系首页展示。`openingMessage` 只在该伙伴还没有聊天记录时插入第一条，不放进系统提示词。`lorebookId` 先不整本注入。`isPublic` 只决定能否出现在广场。

换卡时必须明示：沿用旧记录，或清空这段记录再用开场白。不要让上一张卡的回复留在那 6 条历史里。

仍保持：一个当前活跃伙伴、底栏先到关系首页、Feed / 好友 / 私信是主路径。广场不是第二套聊天室。

---

## 4. 调试时只看一张分段表

先改聊天里「这一轮会带上多少」，让它显示服务端拼出来的段，而不是本地估算。每段要有名称、字数、是否被裁。

对不上时按这个判断：

| 现象 | 原因 |
|------|------|
| 模型段里还有整段人设 | 广场仍在写托管模型，合并没切完 |
| 卡上有人设，前缀字数是 0 | `agent_id` 没绑上，或拼装没读 `AiAgent` |
| 弹窗有人设，回复不像这个人 | 弹窗是本地估算，模型吃的是另一段 |
| 换卡后还是上一张的口吻 | 旧回复仍在最近 6 条里 |
| 开场白每轮都出现 | 开场白被写进了系统提示词 |

验收四张卡：官方模板、一张公开卡、一张只有开场白的卡、一张长过预算的卡。每张都走「广场选用 → 关系首页名字变了 → 再发一句 → 分段表里只有这张卡的前缀」。

---

## 5. 下一刀建议动的文件

只做这条链路，不要顺手改 Arena、记忆提取或模型供应商。

- `backend/internal/biz/companion/llm.go`：按第 3 节重拼；改掉文件头过期注释。
- `lib/pages/ai/character_card_plaza_page.dart`：`_applyCard` 改为绑定当前伙伴，不再 `upsertAgentPrompt`。
- `lib/pages/ai/companion_profile_edit_page.dart`：提示词保存与资料保存对齐到同一张卡。
- `lib/pages/companion/companion_chat_page.dart`：字数弹窗改读服务端分段。
- 契约若要新增「当前卡分段」字段，改 `backend/api/companion/v1/companion.proto` 后 `cd backend && make gen`，再 `make check`。禁止手改 `*.pb.go`。

Flutter 页面继续走现有域服务，不在页面里直接调 `ApiClient`。
