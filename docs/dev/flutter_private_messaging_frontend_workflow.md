# Flutter 私信与保留策略 — 前端工作流备忘

本文记录当前实现中与 **私信持久化 REST**、**本地缓存**、**用户保留偏好** 相关的前端流程，便于后续迭代时对照。后端契约见 `backend/docs/private_messages.md`。

---

## 1. 路由与入口

| 入口 | 说明 |
|------|------|
| 底栏 **「联系人」→ 子 Tab「消息」** | `FriendsPage` 内嵌 `ConversationsPage(embedded: true)`：聚合好友、通知中心私信、本地 `direct_chat_*` 缓存键、WS 未读 `ChatPushService.unreadBySender`；点进 `/direct-chat`。 |
| `/messages` | 独立全屏 `ConversationsPage()`，便于深链或外部跳转（与联系人内嵌页逻辑一致）。 |
| `/direct-chat` | 单聊页 `DirectChatPage`，参数 `Map`: `userId`, `username`, `avatar`（与好友/发现等 `pushNamed` 一致）。 |
| `/message-retention-settings` | 「私信记录保留」设置页；也可从设置搜索命中后 `Navigator.pushNamed`。 |
| 设置主页 `SettingsPage` | 区块 **「聊天与隐私」** → 列表项进入 `MessageRetentionSettingsPage`（`MaterialPageRoute`）。 |

`main.dart` 中已注册上述命名路由（私信保留页为独立 route）。

### 1.1 离线 / 对端不在线

- 后端在 WS **投递失败**时会把摘要写入 **通知表 type=6**（见 `chatwslogic`）。  
- 前端进入单聊时 **`_mergeDmNotificationsFromApi`** 会拉多页通知，并把 **已读 + 未读** 的私信通知合并进气泡（在拉 REST 之前执行），避免仅依赖旧本地缓存时列表为空。  
- 完整正文仍以 **`GET /api/private-messages`** 为准；若线上仍是**旧后端**（无该 REST / 无 `private_messages` 表 / 未落库），需 **部署新版本并 `-migrate`**，否则只能看到通知里的截断摘要。

---

## 2. 数据模型（Dart）

- **`lib/models/private_message_item.dart`**  
  对齐后端 `PrivateMessageItem`：`id`, `sender_id`, `receiver_id`, `sender_moe_no`, `receiver_moe_no`, `body`, `image_paths`, `retention_days`, `created_at`, `expires_at`。

- **`lib/models/user.dart`**  
  新增字段：`display_user_id` → `displayUserId`；`message_retention_choice` → `messageRetentionChoice`（0=自动，7/30 为用户自选，与后端一致）。

---

## 3. API 封装（`ApiService`）

- **`listPrivateMessages`**  
  `GET /api/private-messages?peer_user_id=...&limit=...&before_id=...`  
  返回 `(items: List<PrivateMessageItem>, hasMore: bool)`。需 JWT。

- **`updateUserInfo(..., messageRetention: 'auto' \| '7' \| '30')`**  
  `PUT /api/user/:userId` body 中带 `message_retention`（可选）。

- 原有 **`getUserInfo`** 用于设置页加载当前策略展示。

---

## 4. 单聊页 `DirectChatPage` 流程（核心）

### 4.1 初始化顺序（`_initChat`）

1. 取当前用户 ID（`AuthService.getUserId`）。
2. **`_loadMessages`**：从 `SharedPreferences` 读本地 JSON（按两用户 ID 排序后的 key），恢复 `_DirectMessage` 列表（含可选 `serverId`）。
3. **`_fetchInitialServerHistory`**：  
   - `listPrivateMessages(peer_user_id: 对方, limit: 40)`；  
   - 将每条服务端记录 **`_expandServerItem`** 展开为 1～多条气泡（正文 `id#t`，每张图 `id#i0`…）；  
   - **`_applyMergedLocalAndServer`**：服务端为主，合并未在服务端出现的本地-only 记录（短窗口内容去重）；  
   - 更新 **`_hasMoreServer`**、**`_oldestServerCursorId`**（当前页中 **时间最旧** 一条的 `id`，即 `items.first.id`，因接口 `data` 为旧→新）；  
   - 再 `_saveMessages`、`_scrollToBottom`。
4. **`_mergePendingWsMessages`** / **`_syncOfflineMessages`**：与原先一致（通知、离线队列）。
5. **`_connectWebSocket`**：`ChatPushService.incomingMessages` 收下行。

### 4.2 分页「更早消息」

- **`ScrollController`** 监听：接近 **`maxScrollExtent`**（`reverse: true` 列表的「顶部」= 更旧方向）时触发 **`_loadOlderServerPage`**。
- 使用上一批最旧行的 **`before_id = _oldestServerCursorId`** 再请求；新消息 **`insertAll(0, ...)`** 后按时间排序；去重依赖 **`serverId`**。
- 加载中在页面上方展示 **`LinearProgressIndicator`**（细条）。

### 4.3 气泡内容与图片

- 与历史一致：图片内容仍为 **`[IMG]` + URL**（`resolveMediaUrl`）。  
- 服务端 `image_paths` 中的文件名会拼成 `/api/images/<name>` 再解析为完整 URL。

### 4.4 WebSocket 与 `serverId`

- 下行若带 **`server_message_id`**，通过 **`_serverSlotFromWsId`** 写成与 REST 对齐的槽位（文本 `$id#t`，以 `[IMG]` 开头则 `$id#i0`），避免与已拉取的历史重复。

### 4.5 本地持久化

- Key：`direct_chat_${min(current,peer)}_${max(...)}`（与原先一致）。  
- 每条消息 JSON 字段：`senderId`, `content`, `time`, 可选 **`serverId`**。

---

## 5. 私信保留设置页 `MessageRetentionSettingsPage`

1. `AuthService.getUserId` → `getUserInfo` 展示当前 `message_retention_choice`。  
2. 单选：`auto` / `7` / `30`。  
3. 保存：`updateUserInfo(userId, messageRetention: ...)`，Toast 提示。

---

## 6. 与后端文档的对应关系

| 前端行为 | 后端参考 |
|----------|----------|
| 列表分页 `before_id` / `has_more` | `private_messages.md` §4.2 |
| 展示 Moe 号（若将来 UI 要用） | 接口字段 `sender_moe_no` / `receiver_moe_no` |
| 保留策略 | `PUT` `message_retention` + `User.message_retention_choice` |

---

## 7. 会话列表 / 「消息」分区

- 底栏 **「联系人」** 首个子 Tab **「消息」**（或路由 **`/messages`**）→ **`ConversationsPage`**：聚合好友、通知中心私信、本地缓存键、`unreadBySender`；点击进入 **`/direct-chat`**。  
- 与某人的**完整历史与分页**仍在 **`DirectChatPage`** 内（**`GET /api/private-messages`** + 本地缓存 + 通知摘要合并）。

## 8. 后续可改进（未做）

- WS 发送失败时 **`POST /api/private-messages`** 兜底重试。  
- 单聊 AppBar 展示对方 **`display_user_id` / moe_no`**。  
- 清空聊天记录时同步清理本地 key 与 UI（当前菜单项多为占位）。  
- 后端增加「会话列表」接口后可替换前端的纯聚合逻辑。

---

*文档随实现变更时请同步更新本节与代码注释。*
