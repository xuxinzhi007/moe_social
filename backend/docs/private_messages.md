# 私信持久化（Private Messages）— 后端说明与前端对接

本文描述 `private_messages` 表、REST 接口、与 **WebSocket `/ws/chat`** 的配合方式，以及 **图片路径**、**VIP 留存天数** 的配置约定。

---

## 1. 数据模型

表名：`private_messages`（GORM 模型 `model.PrivateMessage`）。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | uint | 主键 |
| `sender_id` | uint | 发送方用户 ID |
| `receiver_id` | uint | 接收方用户 ID |
| `body` | text | 正文（UTF-8 字符数上限见配置 `body_max_runes`，默认 8000） |
| `image_paths` | text | JSON 数组字符串，如 `["a.png","b.jpg"]`，见下文「图片路径」 |
| `retention_days` | uint8 | **写入时快照**：按发送方当时 VIP 状态计算的天数（1–255） |
| `expires_at` | datetime | `created_at + retention_days`，过期后由定时任务硬删除 |
| `created_at` | datetime | 创建时间 |

会话维度：任意两人 A、B 的往来为  
`(sender_id=A AND receiver_id=B) OR (sender_id=B AND receiver_id=A)`。  
列表接口已按该条件过滤，且只返回 **`expires_at > NOW()`** 的行。

---

## 2. 保留天数（VIP 与普通用户）

配置位置：`backend/config/config.yaml`（与数据库等同级，RPC 启动时已 `InitConfig` 可读）。

```yaml
private_message:
  retention_days_default: 30   # 当 normal 未配置或 ≤0 时使用
  retention_days_normal: 7   # 发送方非有效 VIP
  retention_days_vip: 90     # 发送方有效 VIP：IsVip 且 VipEndAt > 当前时间
  body_max_runes: 8000
  image_paths_max: 9
```

规则（实现于 `utils.PrivateMessageRetentionDaysForSender`）：

- 发送方 **有效 VIP** → `retention_days_vip`（默认 90，未配置则 90）。
- 否则 → `retention_days_normal`；若未配置或 ≤0，则用 `retention_days_default`；仍无则 **30**。

**后续扩展「会员自定义保存天数」**：可在用户表或 VIP 套餐表增加字段（如 `message_retention_days`），在 `PrivateMessageRetentionDaysForSender` 中优先读取；当前未接 DB 字段，仅 YAML 分档。

---

## 3. 图片路径（与现有云空间一致）

- 图片文件落在 **`Image.LocalDir`**（`api/etc/super.yaml`，可被 `backend/config/config.yaml` 的 `image.local_dir` 覆盖）。
- 对外访问 URL 形态与列表接口一致：`{api_base}/api/images/{filename}`（`api_base` 来自 `GET /api/public/client-config` 或请求 Host，见 `getimagelistlogic`）。

**写入 `private_messages.image_paths` 的约定**：

- 只存 **文件名**（与 `GET /api/images/list` 里返回的 `filename` / `id` 一致），例如 `abc.png`。
- **禁止** 路径分隔符、`..`；仅允许安全字符集（字母数字 `._-`）。
- 每条消息最多 **`image_paths_max`** 条（默认 9）。

前端展示：用 `api_base_url + "/api/images/" + encodeURIComponent(name)` 拼接（注意与 HTTPS/端口一致）。

---

## 4. REST API（需 JWT）

鉴权：与其它 `jwt: Auth` 路由相同，Header `Authorization: Bearer <token>`。  
当前用户 ID 由中间件注入 context，**不信任 body 里的 sender**。

### 4.1 发送（推荐：REST 为主，WS 为辅）

- **POST** `/api/private-messages`  
  成功后服务端会 **与 WS 路径一致**：向对端已连接 `/ws/chat` 的会话推送同构 JSON（含 `server_message_id`、`timestamp` 等）；对端无 WS 时仍写 **通知 type=6**。Flutter 客户端已改为 **优先走本接口** 发送，避免仅依赖 WS 时 RPC 异常导致不落库。
- Body JSON：

```json
{
  "receiver_id": "123",
  "body": "文本内容",
  "image_paths": ["a.png"]
}
```

- `image_paths` 可选；缺省或空数组表示纯文本。

成功响应 `data` 为单条 `PrivateMessageItem`（含 `id`、`sender_id`、`receiver_id`、`sender_moe_no`、`receiver_moe_no`、`expires_at`、`retention_days` 等）。**界面展示 Moe 号请用 `sender_moe_no` / `receiver_moe_no`；请求入参与分页游标仍用数字主键字符串 `sender_id` / `receiver_id` / `peer_user_id` / `before_id`。**

### 4.2 拉取与某人的历史（分页）

- **GET** `/api/private-messages?peer_user_id=123&before_id=&limit=30`
- `peer_user_id`：对方用户 ID（字符串）。
- `before_id`：可选，上一页最旧一条的 `id`，用于「加载更早」；不传则从最新往旧取。
- `limit`：默认 30，最大 100。
- 返回 `data`：**时间正序**（旧 → 新），便于气泡列表直接渲染；`has_more` 表示是否还有更早消息。

错误形态与其它接口一致：`BaseResp` 中 `code` / `message`。

---

## 5. WebSocket `/ws/chat` 与落库

在 `type: "message"` 的处理中，服务端会：

1. 调用 **RPC `SendPrivateMessage`** 写入 `private_messages`（含 `image_paths` 解析，见 WS JSON 字段 `image_paths` 或 `imagePaths` 数组）。`to` / `target_id` **支持字符串或 JSON 数字**。
2. 落库成功后使用与 **POST `/api/private-messages`** 相同的投递逻辑：向对端 **WS 推送**（`from`、`content`、`timestamp`（毫秒）、`time`（RFC3339）、`server_message_id`、`expires_at`、`sender_moe_no`、`receiver_moe_no` 等）。若 RPC 失败，向发送方回推 `type: "private_message_error"`。
3. 若对端 **未连接 WS**，仍会落库；并保留 **通知表 type=6** 兜底（`CreateNotification`），便于通知中心提醒。

**POST** 发送在 RPC 成功后走 **同一套投递**（实时 WS + 离线通知）。

---

## 6. 过期清理

RPC 进程启动后注册 **每 6 小时** 执行一次：`DELETE FROM private_messages WHERE expires_at < NOW()`（硬删除，无软删）。

也可在运维侧增加 **MySQL Event / cron** 做同样删除，与文档 SQL 一致即可。

---

## 7. 数据库迁移

表结构由 GORM `AutoMigrate` 创建。新增模型后请执行：

```bash
cd backend/rpc
go run super.go -f etc/super.yaml -migrate
```

---

## 8. 前端对接清单（摘要）

| 能力 | 方式 |
|------|------|
| 发消息 + 持久化 | **推荐** `POST /api/private-messages`（服务端写库并 WS/通知投递）；仍兼容仅用 WS `type: "message"` |
| 历史列表 | `GET /api/private-messages?peer_user_id=...` |
| 实时收信 | 原有 WS `type: "message"` |
| 图片 | `image_paths` 存文件名；展示用 `client-config` 的 `api_base_url` + `/api/images/` + name |
| 会员时长 | 读配置或后续用户字段；当前由服务端按 VIP 写 `retention_days` / `expires_at` |

---

## 9. 用户标识：主键与 Moe 号（私信已落实）

| 层面 | 约定 |
|------|------|
| **查询、分页、`peer_user_id` / `receiver_id` / JWT** | 仍用 **`users.id` 数字主键**（字符串形式）。 |
| **展示** | `PrivateMessageItem`（及 WS 推送里同名字段）增加 **`sender_moe_no`、`receiver_moe_no`**，由服务端查 `users.moe_no` 填充；未分配 Moe 号时可能为空字符串。 |
| **全站其它接口** | 可按同样模式逐步加「展示用 moe」字段；本次仅私信消息链路与 WS 推送。 |

若后续需要 **仅传 `receiver_moe_no` 发私信**，可再增加解析与校验（moe_no → id）单独排期。

---

## 10. 前端消息：分页策略与交互（推荐游标 + 向上翻历史）

**不要每次全量拉取。** 消息可能很多且有过期删除，全量浪费流量、首屏慢。应使用文档已有能力：**游标分页**（`before_id` + `has_more`）。

### 10.1 接口语义（与后端对齐）

- **首屏**：`GET /api/private-messages?peer_user_id={对方主键}&limit=30`（不传 `before_id`）。  
  返回的 `data` 为 **时间正序：旧 → 新**（数组 **第一个最旧，最后一个最新**）。
- **加载更早**：用户 **向上滚动到列表顶部**（或顶部下拉）时，取当前列表中 **最小的 `id`**（即当前已加载片段里最旧一条），请求：  
  `GET ...&peer_user_id=...&before_id={该最小id}&limit=30`  
  将返回的数组 **拼到现有列表前面**（更旧的消息在前），注意 **按 `id` 去重**，避免与 WS 重复插入同一条。
- **是否还有更早**：看响应 **`has_more`**；为 `false` 时不再请求。

### 10.2 UI 与列表控件（Flutter 思路）

1. **进入会话**：首屏请求完成后，**滚动到底部**（对齐到「最新一条」在视口底部）。  
2. **列表方向**：`data` 已是旧→新，可用普通 `ListView`（不 reverse），首条在顶部、末条在底部；或用 `reverse: true` 时在内存里 **反转数据顺序** 与滚动语义二选一，团队内统一一种即可。  
3. **上拉 / 触顶加载**：监听滚动位置，`pixels <= threshold` 时触发加载更早；加 **loading 锁**（`isLoadingHistory`）防止重复请求。  
4. **与 WebSocket 对齐**：WS 推送若带 `server_message_id`，与本地列表 **按 id 去重**；若仅实时无 id，可用时间+内容临时键，收到 REST 首屏后再以服务端 `id` 为准归并（可选优化）。  
5. **发送**：可继续走 WS（服务端已写库）；发送成功后本地 **乐观插入** 或等 WS 回推再插入，与 `POST /api/private-messages` 二选一策略产品定。

### 10.3 不建议的做法

- 每次打开会话 **无 `before_id` 拉全表**（在 VIP 长留存下可能上千条）。  
- 仅用 `page/page_size` 而不用 `before_id`：在 **中间有新消息插入** 时容易错位；当前后端提供的是 **游标**，更适合 IM。

---

## 11. 待你确认（可选）

1. **私信发件/收件人入参**：是否需要在下一迭代支持 **`receiver_moe_no`**（后端解析成 id），还是 Flutter 侧始终持有对方 **数字 id**（从资料页带入会话）即可？  
2. **会话列表页**：本阶段是否只做「点进某个用户后的单聊线程」，还是同时要 **会话列表聚合**（最后一条预览、未读数）？后者需要额外接口或扩展现有通知/未读模型。

---

更多字段以 `api/internal/types/types.go` 中 `PrivateMessageItem`、`SendPrivateMessageReq` 为准（随 `goctl` 生成可能微调 json tag）。
