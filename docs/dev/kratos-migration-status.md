# Kratos 迁移 — 进度清单



> **更新：2026-05-27**  

> **当前阶段：Sprint F100d**  

> **全站迁移 F：~99.5%** · **工程就绪度 G：~65%**  

> 口径：[kratos-full-site-migration-plan.md §1](./kratos-full-site-migration-plan.md#1-进度口径必读避免歧义) · 路线图：[kratos-migration-sprint-f100.md](./kratos-migration-sprint-f100.md)



---



## 总览



| 曲线 | 进度 | 验收 |

|------|------|------|

| A · Hybrid Moe | **100%** | `make verify-moe-complete` |

| B · 纯 Kratos 试点 | **100%** | `make verify-kratos-100` |

| **F · 全站迁移** | **~99.5%** | `make verify-sprint-f100d-community` |

| G · 工程现代化就绪 | **~62%** | Hybrid 可上线；≠ 契约拆分完成 |



**F=100% 定义**：各域 biz 100% + 域 proto 拆分 + 退役 `super.*`（见 F100 FS-8～10）



---



## 当前生产架构（网关）



| 网关 | 路由 | 覆盖 |

|------|------|------|

| `moeadmingw` | in_process | Moe Admin |

| `vipadmingw` | in_process | VIP 套餐 |

| `usergw` | in_process | User + 通知 inbox |

| `landinggw` | in_process | Landing |

| `behaviorgw` | in_process | 行为埋点 |

| `admingw` | in_process | 只读/notify/公告 CRUD/审计/礼物 CRUD |

| `postgw` | in_process | search/get/list/create/like/delete/update/report |

| `commentgw` | in_process | list/create/like |

| `checkinwg` | in_process | 签到/等级/经验日志 |

| `achievementgw` | in_process | 成就读 + ensure |

| `giftgw` | in_process | 礼物读+send/purchase+记录/订单 |

| `llmgw` | in_process | models/catalog/config + chat-turn 持久化 |

| `communitygw` | in_process | 群组 CRUD + 成员 + 群帖 |

| 其余 HTTP | super RPC | AI agents/chat raw 等 |



配置：`moe.*_api_in_process`（`config/config.yaml`）



---



## 已完成 ✅



### Sprint F70 + F80 + F90（部分）



- [x] F70 S1～S5 — `make verify-sprint-f70`

- [x] F80-U1 User 通知 — `make verify-sprint-f80-u1`

- [x] F80-A1 Admin 公告 list/get — `make verify-sprint-f80-a1`

- [x] F80-P1 Post search/get/list — `make verify-sprint-f80-p1`

- [x] F90 评论 list + Admin audit list — `make verify-sprint-f90`

- [x] F92 Post/Comment create 写路径 — `make verify-sprint-f92-social-write`（成就经 `socialhook` 注册）

- [x] F94 Post/Comment like — `make verify-sprint-f94-social-like`

- [x] F96 Post delete/update/report — `make verify-sprint-f96-social-mutate`

- [x] F97 Admin 公告写路径 — `make verify-sprint-f97-admin-announcements-write`

- [x] F98 `pkg/achievement` + `pkg/level` 抽包 — `make verify-sprint-f98-achievement-pkg`

- [x] F99 Checkin + Achievement HTTP — `make verify-sprint-f99-community-checkin`

- [x] F100a Gift 读+写全路径 — `make verify-sprint-f100a-gift`

- [x] F100b LLM models/catalog + chat-turn — `make verify-sprint-f100b-llm`

- [x] F100c-a Admin 礼物 list/get — `make verify-sprint-f100c-admin-gifts-ro`

- [x] F100c-b Admin 礼物写 CRUD — `make verify-sprint-f100c-admin-gifts-write`

- [x] F100d Community 全路径 — `make verify-sprint-f100d-community`



### 历史



- [x] FS-2 VIP · FS-3 User · FS-3c 小域 · A/B 100%



---



## 各域域内进度



| 域 | 域内 % | biz / gw |

|----|--------|----------|

| Moe | 100% | `biz/moe` + `moeadmingw` |

| VIP | 100% | `biz/vip` + `vipadmingw` |

| User | 100% | `biz/user` + `usergw` |

| 其它 | 100% | landing/behavior/appcfg |

| 平台 | 100% | `moe-social` |

| Admin | ~62% | 公告/审计/notify + 礼物 CRUD 全 in_process |

| 通知 | ~60% | inbox + 广播 |

| 社交 | ~90% | post/comment + community 群组全路径 |

| 社区/签到 | ~85% | community 全路径 + checkin/achievement |

| Gift | ~90% | 用户侧读+send/purchase 全 in_process |

| AI / LLM | ~35% | models/catalog/config + chat-turn in_process；chat 推理仍 API logic |

| Chat / Voice | 0% | legacy |



---



## 待办 ⬜（F 99.5% → 100%）



- [ ] AI/LLM chat 推理与 memory 写路径 biz 化

- [ ] AI agents/providers 域（`logic/ai`）

- [ ] Chat/Voice/WebSocket 边界

- [ ] Admin 剩余 CRUD（用户/成就/菜单等）

- [ ] FS-8 域 `api/<domain>/v1/*.proto`

- [ ] FS-9 退役 `super.api` / `super.proto`



---



## 日常命令



```bash

cd backend

make verify-sprint-f80      # F80 回归

make verify-sprint-f100d-community          # F100d community 全路径
make verify-sprint-f100c-admin-gifts-write  # F100c-b admin 礼物写
make verify-sprint-regression              # F100d→F70 全回归

make verify-sprint-f90        # F90 部分

make verify-sprint-f100-structure  # GW + biz 结构门

make moe-social

powershell -File scripts/verify-sprint-f70.ps1   # Windows

```

