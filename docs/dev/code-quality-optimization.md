# 代码质量优化计划

日期：2026-06-03

## 当前结论

项目可以继续实现，但当前优先级应从“继续扩功能”切到“收束主线 + 降低维护成本”。本轮不处理充值真实支付，充值页继续保留模拟状态。

## 本轮边界

- 保持充值模拟，不改充值扣费、支付渠道、订单闭环。
- 不改 API / proto 契约，避免牵动后端生成代码。
- 优先拆纯 UI 组件和无副作用 helper，再拆状态与服务。
- 每轮拆分后跑 `flutter analyze` 或目标测试，结果必须记录。

## 优先处理对象

| 优先级 | 文件 | 当前问题 | 建议方向 |
| --- | --- | --- | --- |
| P0 | `lib/pages/ai/chat_page.dart` | 2600+ 行，混合会话、缓存、语音、搜索、模型请求和 UI | 先拆 `widgets/ai` 纯展示组件，再提会话/搜索/语音 controller |
| P0 | `lib/services/api_service.dart` | 2200+ 行，跨多个业务域 | 按 auth/user/feed/chat/commerce 拆 domain service，保留 facade 过渡 |
| P1 | `lib/pages/ai/ollama_chat_page.dart` | 2100+ 行，和 AI chat 能力重叠 | 与 Chat Gateway 对齐，能复用则复用组件 |
| P1 | `lib/services/update_service.dart` | 1700+ 行，更新检测、下载、平台处理耦合 | 拆版本解析、下载器、平台安装适配 |
| P1 | `lib/pages/profile/friends_page.dart` | 1600+ 行，列表、请求、操作和 UI 混合 | 拆 tab/list item/action service |

## 幻想实现处理策略

| 类型 | 当前策略 |
| --- | --- |
| 充值模拟 | 暂时保留，页面文案继续明确“模拟充值” |
| 扭蛋 / 背包 mock | 后续应对齐后端奖池和库存，本轮只记录不改 |
| 内容生成占位 | 后续接真实生成服务或从产品入口降级 |
| AutoGLM Web 模拟 | 保留为 UI 演示，但需避免对外宣称 Web 可真实执行 |
| 管理台 planned 页面 | 保留占位页，但菜单状态必须标明 planned / partial |

## 拆分原则

1. 先拆 StatelessWidget / 纯函数，不碰业务状态。
2. 新组件只接收必要 props 和 callback，不读取父页面私有状态。
3. 页面文件保留流程编排：发送、加载、持久化、导航。
4. 服务文件按业务域拆，旧入口保留一段时间作为 facade。
5. 每次有效 diff 控制在小范围，避免一次性重写大页。

## 验收口径

- `flutter analyze` 不新增 error；已有 warning/info 分批清理。
- 后端相关改动必须 `cd backend && go test ./...`。
- Flutter 测试若因本机 SQLite / Xcode SDK 环境失败，需要明确说明，不伪装为通过。
