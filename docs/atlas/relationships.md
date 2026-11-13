# 关系稿 · 人、内容、伙伴、生命

这是当前持久化对象怎么连在一起。身份以 `backend/model/` 的主键和外键为准。术语：用户是社交账号；伙伴是该用户的一条 AI 陪伴档案；生命是某个世界里的居民。三者不是同一个东西。伙伴可以记下一个 `LifeEntityID`，那是桥，不是合并。

打开 [relationships.html](./relationships.html) 看同一张图。状态机的每个取值没有在这篇展开，改状态前回到对应 biz 的 const。

## 对象（已证实）

| 对象 | 模型 | 身份 |
|------|------|------|
| 用户 | `model.User` | `ID`；`Username`、`MoeNo`、`Email` 唯一。密码 bcrypt，JSON 不输出 |
| 帖子 | `model.Post` | `ID`，归属 `UserID` |
| 评论 | `model.Comment` | `ID`，挂 `PostID`；`ParentID=0` 为一级评论 |
| 点赞 | `model.Like` | `UserID` + `TargetType`（`post`/`comment`）+ `TargetID` |
| 关注 | `model.Follow` | 一对 `(FollowerID, FollowingID)` 唯一 |
| 好友申请 | `model.FriendRequest` | `(FromUserID, ToUserID)` 唯一；`Status` 为 `pending` / `accepted` / `rejected`。注释写明同意后双方互相关注 |
| 私信 | `model.PrivateMessage` | `SenderID`、`ReceiverID`；写入时快照 `RetentionDays`，`ExpiresAt` 后物理删除 |
| 群 | `model.Group` | `CreatorID` → 用户；成员 `GroupMember`（`admin`/`member`） |
| 伙伴档案 | `model.CompanionProfile` | `UserID` 唯一：当前是一用户一条活跃档案 |
| 伙伴记忆 | `model.CompanionMemory` | `UserID` + `HeroID`（空串=主伙伴） |
| 世界 | `model.LifeWorld` | `Name` 唯一 |
| 生命 | `model.LifeEntity` | `ID`；`WorldID` 写入的是世界名（`internal/biz/life/tick.go` 使用 `engine.config.WorldName`） |
| 生命关系 | `model.LifeRelationship` | 同一世界内 `(WorldID, EntityID, TargetID)` 唯一；`RelationType` 默认 `friend`，另有 `Affinity` |

## 三条图，中间有一座桥

### 1. 社交图

用户发出帖子。帖子挂话题（`PostTopic` 连接 `Post` 与 `TopicTag`）。评论挂帖子，评论可以再挂父评论。点赞指向帖子或评论。关注是用户到用户的有向边。好友申请是另一条边，同意之后才变成互相关注，不单独做第三种好友表。私信是用户到用户的消息，带过期时间。群由创建者拥有，成员通过 `GroupMember` 加入。

用户还可以是机器人：`User.IsBot` 与 `BotAgentKey`。那仍是一条 `user` 行，用来让智能体出现在社交图里。

### 2. 伙伴图

`CompanionProfile.UserID` 唯一，所以现在每个用户只有一条当前伙伴。档案上有名字、人设、`RelationshipLevel`（1–10）、`IntimacyScore`（0–100），以及主动打招呼的时段。记忆行挂在同一个 `UserID` 上，`HeroID` 空串表示主伙伴，非空则是星辉英雄 slug。模型注释写明：多角色不要在业务层再写死「永远一个」；演进是多行加活跃标记。见 `docs/dev/ai-companion-formal-decisions.md`。

### 3. 生命图

`LifeWorld` 按名字标识一个世界。`LifeEntity.WorldID` 存的是这个名字，不是 `LifeWorld.ID`。居民有饱食、精力、心情、位置和成长阶段。`LifeRelationship` 只连接同一世界里的两个居民，和用户之间的 `Follow` 不是同一套关系。

运行时居民状态在内存里走 tick；表是存档和冷启动。事件进 `life_event_log`。

### 桥

`CompanionProfile.LifeEntityID`（默认 0）把伙伴指到一个居民。头像字段注释写明：关系层头像和 Life 居民形象分开。产品定位也把 Life 收成星辉活世界内核，不把生命模拟放进社交主路径（`arenaGamePrototype` 当前为 false）。

## 不要混用的词

| 词 | 指什么 | 不要当成 |
|----|--------|----------|
| 用户 | `user` 行 | 伙伴、居民、管理台账号（`admin_account` 是另一张表） |
| 好友 | 好友申请被接受后的互相关注 | 生命之间的 `LifeRelationship` |
| 伙伴 | `companion_profiles` 一行 | 酒馆多角色、Life 居民 |
| 居民 / 生命 | `life_entities` 一行 | 用户的社交身份 |
| 世界 | `life_worlds.Name` | 社区群组 `Group` |

## 商业与账号旁路（已证实，模型存在）

`User` 上有 `IsVip`、`VipEndAt`、`Balance`、`GiftCharm`。配套表有 `vip_plan`、`vip_order`、`gift`、`transaction`。它们挂在用户上，不进入上面三条主图的中心。主视觉不以钱包为重心（产品定位 P2）。
