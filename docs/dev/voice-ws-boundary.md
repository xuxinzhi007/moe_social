# Voice / WebRTC 边界（Hybrid Kratos）

> **更新：2026-05-28** · Sprint F112（F107 基线 + 展示名收口）  
> SSOT 契约：`api/chat/v1/private_message.proto`（私信）；Voice 暂无独立 proto，HTTP 走 `super.api`。

---

## 分层

| 层 | 路径 | 职责 |
|----|------|------|
| **信令 HTTP** | `api/internal/logic/voice/*` | 发起/接听/拒绝/取消通话；签发 RTC token |
| **实时推送** | `api/internal/logic/chat/*` WS | `incoming_call` 等 JSON 经 **Chat WS** 投递（`PushJSONToChatUser`） |
| **会话状态** | `api/internal/logic/voice/call_registry.go` | 进程内 call session（非 DB） |
| **用户资料** | `UserGW.GetUser` via `ResolveVoiceUserDisplay` | 主叫昵称/头像（F112 统一 helper） |
| **RTC** | Agora/配置 | `getrtctokenlogic` 读 `config.yaml` |

**不经过 RPC**：Voice 信令不调用 `SuperRpcClient`（F107 已去掉 `GetUser` 直连 super）。

---

## 与 Chat 域关系

```text
VoiceCall HTTP → call_registry + UserGW
              → Chat WS 推送 incoming_call（receiver 在线）
私信 SendPrivateMessage → ChatGW → biz/chat（F106）
私信 List* → ChatGW → biz/chat（F107）
```

离线来电：**无**持久化队列；receiver 不在 Chat WS 时仅打日志（见 `voicecalllogic.go`）。

---

## 未来 `voicegw`（可选）

当需 in_process 统一或单测隔离时，可新增：

```text
biz/voice → service/voice → voicegw → moewiring/api_voice.go
```

当前规模下 **信令留在 API 层 + UserGW** 即可；RTC token 与 call registry 无 DB 写，不必强行 biz 化。

---

## 验收

- `make verify-sprint-f107-chat-read`（含 Voice UserGW 检查）
- 联调：`make moe-social-stop && make moe-social`，App 发起语音通话 + Chat WS 在线收 `incoming_call`
