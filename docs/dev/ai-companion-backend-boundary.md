# AI 伙伴后端边界收敛

## 背景

AI 伙伴曾由 Flutter、Companion service 和 AI resource service 分别决定用户、伙伴实体和资源契约，存在用户数据串用、伙伴身份不一致以及 service 直接构造 data store 的问题。

本次参考 `data-service` 的 Kratos 分层方式，先收敛 Companion 与 AI resource 两个域，不同时引入 Google Wire，避免与现有手写 wiring 双轨运行。

## 方案

- 请求身份只由 HTTP JWT context 提供，客户端请求体中的 `user_id` 不参与资源归属判断。
- Companion REST、SSE、WebSocket 均按 actor user ID 隔离 Profile、记忆、聊天和推送。
- `companion_profiles.life_entity_id` 是伙伴与 Life Entity 绑定的唯一事实来源。
- 首次访问时后端按实体 ID 稳定选择默认伙伴；用户切换后由后端校验并持久化绑定。
- Companion 与 AI resource 的对象创建放在 `internal/platform/moewiring`。
- 应用 service 仅依赖 biz Engine/Usecase，data store 实现 biz 定义的消费侧接口。
- Flutter 只解析契约、展示状态和提交绑定，不决定用户数据归属。

依赖方向：

```text
protohttp -> service -> biz <- data
                         ^
                         |
                      wiring
```

## 影响范围

- Companion Profile、状态、记忆、聊天 SSE 和 WebSocket。
- AI provider、agent、lorebook 云端资源 CRUD。
- AI 伙伴首页和 Life 伙伴选择页。
- 数据库迁移新增 Companion 三张既有模型表。

旧 AI 酒馆（AgentList / 本地 ChatPage / providers）按产品决策**退役向**：不进正式导航，也不是二期多角色载体。  
正式陪伴决策 SSOT：`docs/dev/ai-companion-formal-decisions.md`。  
若复用人设/lore，必须迁入 Companion 契约与 biz 端口，禁止再开双栈大厅；不把 Provider 密钥上传到 Companion。

**多伙伴（未实现）**：一期 `user_id` 唯一对应一条 profile；二期若扩展，在 Companion 域演进（活跃 bond），勿写死「产品永远只能一个」之外的额外全局单例。

## 迁移步骤

1. 部署前执行 `cd backend && make db-migrate`。
2. 轮换服务并确认 Companion 三张表已创建。
3. 使用两个测试账号分别访问 Profile、聊天和 AI resources，确认数据隔离。
4. 旧用户首次访问时由后端创建或补齐 Life Entity 绑定。

## 回滚方案

应用代码可回滚到上一版本；新增表和字段均为向后兼容，不需要删除。不要回滚为固定用户 ID 或信任客户端 `user_id` 的实现。
