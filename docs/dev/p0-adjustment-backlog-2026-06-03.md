# P0 调整清单

日期：2026-06-03

## 结论

当前 P0 不是继续扩功能，而是先把产品主线、AI 核心体验和工程验证能力收住。充值页保持模拟，不纳入本轮 P0。

## P0-0 立即阻塞

| 项 | 证据 | 调整动作 | 验收 |
| --- | --- | --- | --- |
| Flutter 测试跑不起来 | `flutter test` 因缺 `third_party/sqlite3/sqlite3.c` 和本机 iOS SDK 失败 | 补跨平台 SQLite amalgamation 获取脚本，或调整 native asset 测试配置；本机安装/选择完整 Xcode SDK | `flutter test` 至少能进入测试执行阶段 |
| Analyzer 长期红灯 | `flutter analyze` 当前仍有 281 条 warning/info | 先清 warning 级：protected `setState`、unused、dead/null 判断；info 分批处理 | `flutter analyze` 不新增 error，warning 数下降 |

## P0-1 产品主线收束

| 项 | 证据 | 调整动作 | 验收 |
| --- | --- | --- | --- |
| 官网叙事与 App 底栏不一致 | 官网 mock 是「首页/消息/AI/我的」，App 是「首页/同好/社区/探索/我的」 | 定版底栏策略：要么 App 改到官网叙事，要么官网改成现网结构 | 新用户首屏能明确刷动态、发帖、聊天/AI 三个主动作 |
| 探索页职责过重 | 探索混合匹配、AI、小游戏 | 将 AI 酒馆或消息提升为更稳定入口；实验功能移入实验室 | 主路径少于 3 步可进入 AI 聊天或消息 |
| 实验功能默认暴露 | AutoGLM、demo、本地模型设置等偏开发者能力 | 默认隐藏到「实验室」或开发者开关 | 普通用户路径不出现开发者工具入口 |

## P0-2 AI 核心体验闭环

| 项 | 证据 | 调整动作 | 验收 |
| --- | --- | --- | --- |
| AI 聊天页仍过长 | `chat_page.dart` 仍 2383 行 | 继续拆会话、搜索、语音、持久化 controller；页面只保留编排 | 单文件降到 1500 行以内，发送/重试/停止行为不变 |
| Provider 管理体验弱 | 产品文档标注 Provider 管理为 P0 重壳 | 统一 Provider 来源、默认选择、失败提示与配置持久化 | 新建角色能明确看到当前模型来源并成功试聊 |
| 角色卡 / 记忆注入链路仍需稳定 | 产品总览将聊天注入适配角色卡列为 P0 | 梳理 system prompt、persona、memory、lorebook 注入顺序和预算 | 同一角色多轮对话人格稳定，记忆注入可解释 |

## P0-3 工程质量与分层

| 项 | 证据 | 调整动作 | 验收 |
| --- | --- | --- | --- |
| `api_service.dart` 过长 | 2280 行，跨多个业务域 | 按 auth/user/feed/chat/commerce 拆 domain service，保留 facade 过渡 | 新增 API 不再继续塞入总 service |
| 超长页面集中 | 多个页面超过 1000 行 | 先拆纯 UI，再拆状态/服务；每轮小 diff | 每次拆分后 `flutter analyze` 不新增 error |
| 硬编码线上地址 | `lib/utils/config.dart`、`lib/config/moe_api.json`、管理台 placeholder 含公网 IP | 明确配置 SSOT，App 默认从配置/环境读取，文档说明本地/线上切换 | 新克隆项目无需改源码即可切环境 |

## P0-4 安全上线前项

| 项 | 证据 | 调整动作 | 验收 |
| --- | --- | --- | --- |
| JWT 密钥轮换 | `security-and-stability-backlog.md` 列为上线前必须 | 生成新随机串并走环境变量 / secret 文件 | 生产不依赖仓库内旧密钥 |
| Android 签名默认密码 | backlog 指出 Gradle 有默认回退 | 删除默认密码，强制环境变量 | 无签名环境变量时 release 构建直接失败 |
| 生产配置入库风险 | backlog 指出 `config.yaml` 密钥风险 | 确认敏感配置只在服务器侧注入 | 仓库无生产 secret |

## 暂不列 P0

| 项 | 原因 |
| --- | --- |
| 充值真实支付 | 用户已明确保持模拟；页面文案已说明不会真实扣费 |
| 扭蛋 / 背包真实库存 | 属于商业化 P1；若准备公开内测，可先隐藏或标内测 |
| 多角色群聊 / 分支会话 | AI P2 能力，不影响当前核心单聊闭环 |
| 完整插件系统 | 产品总览已明确不建议现在做 |

## 建议执行顺序

1. 先修测试环境：SQLite + `flutter test` 可运行。
2. 清 Flutter analyzer warning 中的高风险项。
3. 继续拆 `chat_page.dart` 与 `api_service.dart`。
4. 定版底栏 / 官网叙事二选一。
5. 稳定 Provider、Persona、Memory、Lorebook 注入链路。
