# UI 组件收口方案与清单

> 状态：规划阶段（未改任何代码）。目标：把当前使用的 UI 收口为可复用组件，方便后续打磨与维护。
> 盘点时间：2026-10-21。基准：`lib/widgets/` 96 个 Dart 文件，`lib/pages/` 107 个 Dart 文件（21 个子域）。

## 一、现状盘点结论

### 1.1 命名体系三套并存

| 前缀 | 位置 | 示例 |
|---|---|---|
| `moe_` | `lib/widgets/` 顶层 | MoeActionRow / MoeMenuCard / MoeEmptyState / MoeToast |
| `ai_` | `lib/widgets/ai/`（26 个） | ai_sheet / ai_scaffold / ai_surface_card / ai_chip |
| 无前缀/业务名 | `lib/widgets/` 顶层 | custom_button / like_button / post_card / personalized_card |

### 1.2 组件内部已有重复

| 能力 | 重复实现 |
|---|---|
| 空状态 | `moe_empty_state` / `ai_empty_state` / `ai_chat_empty_state` |
| 加载 | `moe_loading` / `skeleton_loading` / `ai_loading_skeleton` / `post_skeleton` |
| 底部弹层 | `moe_sheet`(motion) / `ai_sheet` / `dialogs/confirm_dialog` |
| 按钮 | `custom_button` / `like_button` / `moe_like_action_button` |

### 1.3 pages 侧未复用热点（定量）

| 信号 | 数量 | 说明 |
|---|---|---|
| 内联 `BoxDecoration` | 471 处 | 手写圆角/阴影卡片，最大头 |
| 手写 `Chip` | 73 处 | 各页 `_rateChip` / `_moodChip` 等 |
| 手写 `AppBar` | 69 处 | `centerTitle+elevation:0` 组合反复 |
| 裸 `CircularProgressIndicator` | 54 处 | 未用 `MoeLoading` |
| 手写空态文案 | 43 处 | `暂无/还没有` 内联 Column+Icon+Text |

### 1.4 最集中的三处热点

1. **`lib/pages/arena/arena_page.dart`** — 单文件海量手写阴影卡片（`:810/2448/3965/5121` 等 60+ 处）、多个私有 `_rateChip`/`_HeroMetaChip`/`_TowerStatusChip`。
2. **profile 域三页** — `followers_page.dart` / `following_page.dart` / `friends_page.dart` 的 `_buildUserItem` 用户行 + 空态几乎逐字重复（`:132-183` 两文件同构）。
3. **auth 域五页** — `login_page` / `register_page` / `verify_code_page` / `forgot_password_page` / `reset_password_page` 的全宽提交按钮（`width:double.infinity, height:50, 主色, spinner`）。

## 二、收口方案（三层）

### 2.1 分层

```
lib/widgets/
├── base/          # 基础组件（无业务依赖，统一 Moe 前缀）
├── <domain>/      # 域组件（ai/ achievement/ chat/ settings/ ...）
└── (顶层)         # 跨页业务组件（post_card、gift_*、avatar_image ...）
```

### 2.2 命名

- 基础组件统一 `Moe` 前缀：`MoeButton` / `MoeChip` / `MoeEmptyState` / `MoeLoading` / `MoeSheet`。
- 业务/域组件保留语义名：`PostCard` / `GiftBanner` / `AiXxx` / `AchievementXxx`。

### 2.3 三个动作

1. **去重合并** — 组件内部重复收敛为单一基础组件。
2. **pages 替换** — 把 pages 侧未复用热点替换为共享组件。
3. **补文档 + 画廊** — 升级 `COMPONENT_USAGE.md` 为完整组件目录，建 dev 模式组件画廊页。

## 三、分期执行清单

### Phase 1 — 内部去重 + 基础组件定型（风险最低，先做）

- [ ] 空状态合并：`MoeEmptyState` 吸收 `ai_empty_state` / `ai_chat_empty_state`（补 `icon/title/subtitle/action` 参数）。
- [ ] loading 合并：`MoeLoading` 吸收 `skeleton_loading` / `ai_loading_skeleton` / `post_skeleton`。
- [ ] 按钮合并：`custom_button` 升级为 `MoeButton`（primary/secondary/text/loading 态），吸收 `moe_like_action_button` / `like_button` 点赞态。
- [ ] sheet 合并：`moe_sheet`(motion) 定型为唯一 bottom sheet 容器，吸收 `ai_sheet` / `dialogs/confirm_dialog`。
- [ ] 新建 `MoeChip`，吸收 `ai_chip`。

### Phase 2 — pages 热点替换（按域小批量，每批独立可验证）

- [ ] **auth 域**：5 页全宽提交按钮 → `MoeButton`（含 spinner）。
- [ ] **profile 域**：`followers/following/friends` 三页抽 `UserListItem` + `MoeEmptyState`。
- [ ] **arena_page.dart**：手写阴影卡/chip → `MoeCard` + `MoeChip`（单列一批，量最大）。
- [ ] **全局扫尾**：54 处裸 loading → `MoeLoading`；43 处空态 → `MoeEmptyState`。

### Phase 3 — 文档 + 预览页

- [ ] 升级 `COMPONENT_USAGE.md` 为完整组件目录（每个组件：用途/参数/示例）。
- [ ] 建 dev 模式组件画廊页，基础组件各一个可交互示例。
- [ ] 用 `MoeTokens` 统一圆角/阴影/间距常量，逐步替代 471 处手写值。

## 四、验收与注意

- **小批量**：每 Phase 内按域拆批，单批 `flutter analyze` + `flutter test` 通过后再进下一批。
- **不破坏现有调用**：合并组件时先保持旧组件为薄别名（deprecated 指向新组件），确认全量替换后再删。
- **命名遵循现有规范**：参考 `COMPONENT_USAGE.md` 与 `MoeTokens`，不引入新的视觉 token。
- **范围控制**：Phase 1 只做组件层去重，不顺手改 pages 样式；样式收敛归 Phase 2/3。
