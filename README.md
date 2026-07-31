# Moe Social (萌社交) app 前端

使用 **Flutter** 与 **Go / Kratos** 构建的复合型社交产品：萌系社交主线、AI 智能体 / 酒馆化能力、虚拟形象与 VIP 商业化、以及 AutoGLM 自动化实验能力。支持 Android、iOS、Web、Windows、macOS、Linux。

> 产品优先级与路线图见 [docs/product/项目开发总览与当前优先级-2026-05-18.md](docs/product/项目开发总览与当前优先级-2026-05-18.md)。贡献与命令约定见 [AGENTS.md](AGENTS.md)。

## 功能模块（当前已实现）

### 账号与认证
- 邮箱注册 / 登录、验证码、找回密码
- **飞书 OAuth** 登录与账号绑定
- **微信 OAuth** 登录（App / Web；需配置开放平台与 `backend/config/config.yaml`）
- JWT 会话、个人资料编辑、用户二维码

### 社交与内容
- 动态流、发帖（图文 / 手绘等）、评论、点赞、话题
- 关注 / 粉丝、好友请求与好友列表
- 私信、WebSocket 实时消息、在线状态、语音通话（Agora）
- 社区 / 兴趣小组、通知中心、发现页
- 情绪标签、互动礼物、成就徽章（见 [docs/features/NEW_FEATURES_GUIDE.md](docs/features/NEW_FEATURES_GUIDE.md)）

### 成长与商业化
- 签到、用户等级、成就系统
- 钱包、充值、订单中心、VIP 中心与购买流程
- 抽卡、背包、虚拟形象（Rive）相关设置

### AI 与自动化
- AI 智能体列表 / 编辑、多模型聊天、内容生成
- Provider Profile、Lorebook / 世界书、角色卡广场
- 用户记忆管理（[记忆架构](docs/dev/用户记忆系统-OpenClaw式演进设计.md) · [推理与记忆](docs/dev/llm-inference-and-memory-vision.md)）
- **AutoGLM** 子系统（配置、任务执行，见 [docs/autoglm/AutoGLM_README.md](docs/autoglm/AutoGLM_README.md)）

### 其他
- 云相册、扫码、小游戏（扫雷、游戏房间等）
- 主题 / 外观、隐私与消息保留、应用内更新检测
- 静态产品官网：`website/official/`（可部署至 Netlify）；微信开放平台申请资料见 [`website/official/wechat-review/申请指南.md`](website/official/wechat-review/申请指南.md)

部分 AI / 商业能力仍在迭代中；以代码与 `docs/` 为准。

## 技术栈

| 层级 | 技术 |
|------|------|
| 客户端 | Flutter 3.x、Dart、Provider、Material |
| 后端 | Kratos、Protocol Buffers、GORM、MySQL、JWT |
| 实时 / 媒体 | WebSocket、Agora RTC |
| 第三方 | 飞书 / 微信 OAuth、fluwx |

后端详情见 **[backend/README.md](backend/README.md)**。

## 快速开始

### 前提条件

- [Flutter SDK](https://flutter.dev/docs/get-started/install)（`flutter doctor` 通过）
- 后端开发另需 Go 1.25+、MySQL、Protocol Buffers 生成工具（见 `backend/README.md`）

**macOS 安装 Flutter（可选）：**

```bash
brew install flutter
flutter --version
flutter doctor
```

### 前端

```bash
git clone <repo-url>
cd moe_social
flutter pub get
flutter run
```

API 地址在 **`lib/utils/config.dart`** 中配置（`isProduction` / `productionUrl` / `developmentUrl`）。修改后需 **完整重启** App，不要仅热重载。真机调试时 `127.0.0.1` 指向手机本机，应使用电脑局域网 IP 或线上地址。

### 后端（本地）

```bash
cd backend
# 配置 config/config.yaml 中的数据库等
go mod download
make gen          # 修改 api/<domain>/v1/*.proto 后重新生成
make build        # 或分别启动 api / rpc
go test ./...
```

Docker 二进制部署示例（在 `backend/` 目录）：

```bash
docker compose -f docker-compose.binary.yml up -d --build
docker logs moe-social-api
docker logs moe-social-rpc
```

环境联调说明：[docs/dev/环境配置说明.md](docs/dev/环境配置说明.md) · [docs/dev/快速调试步骤.md](docs/dev/快速调试步骤.md)

### 生产构建

```bash
flutter build apk      # Android
flutter build ios      # iOS
flutter build web      # Web
flutter build windows  # Windows
flutter build macos    # macOS
flutter build linux    # Linux
```

## 项目结构

```
moe_social/
├── lib/                    # Flutter 客户端
│   ├── app/                # 路由、主 Shell
│   ├── pages/              # 按域划分：auth、feed、chat、ai、commerce…
│   ├── services/、providers/、widgets/、models/、utils/
│   └── main.dart
├── backend/                # Go / Kratos HTTP（api/<domain>/v1/*.proto）
├── docs/                   # 文档中心 → docs/README.md
├── website/official/       # 静态产品官网
├── test/                   # Flutter 测试
├── android/、ios/、web/、windows/、macos/、linux/
└── AGENTS.md               # 仓库贡献与常用命令
```

## 文档

| 用途 | 链接 |
|------|------|
| 文档总索引 | [docs/README.md](docs/README.md) |
| 浏览器导航 | [docs/index.html](docs/index.html) |
| 记忆系统 SSOT | [docs/dev/用户记忆系统-OpenClaw式演进设计.md](docs/dev/用户记忆系统-OpenClaw式演进设计.md) |
| 部署平台 / Agent | [docs/dev/deploy-platform.md](docs/dev/deploy-platform.md) |
| Code Review | [code_review.md](code_review.md) |
| Kratos 迁移状态 | [docs/dev/kratos-migration-status.md](docs/dev/kratos-migration-status.md) |

## 运维部署台（Deploy Agent）

一体化运维界面：构建后端、管理 Docker、触发 GitHub APK 流水线。按运行 Agent 的机器自动选择 macOS / Windows / Linux 命令。

```bash
cd backend
cp deploy/config.example.yaml deploy/config.yaml   # 修改 token
make deploy-agent
# 浏览器打开 http://127.0.0.1:19010/（需 Agent 在线，勿仅用 IDE 预览 HTML）
```

在 `deploy/config.yaml` 的 `targets` 中配置云平台 SSH。详见 [docs/dev/deploy-platform.md](docs/dev/deploy-platform.md)。

## CI/CD 与自动更新

推送形如 `v*` 的 Tag（例如 `v1.0.3`）会触发 GitHub Actions：构建 Release APK 并发布到 [GitHub Releases](https://github.com/xuxinzhi007/moe_social/releases)。

```bash
git tag v1.0.3
git push origin v1.0.3

# 删除已推送的版本
git tag -d v1.0.3
git push origin :refs/tags/v1.0.3
```

**后端交叉编译 Linux**：在 `backend` 目录执行 `make build-linux`，不要用 `go env -w GOOS=linux` 改写全局环境。详见 `backend/Makefile`。

### 产物与 App 内更新

- APK：[Releases](https://github.com/xuxinzhi007/moe_social/releases)（`app-release.apk`）
- 检测：客户端读后端 `GET /api/public/app-release/latest`（CI 发版后自动回写，见 [docs/dev/app-release-backend.md](docs/dev/app-release-backend.md)）
- **设置 → 常规 → 软件版本** 可手动检查；支持镜像加速下载、进度显示

Release 签名与 CI Secrets：[docs/dev/android-release-signing.md](docs/dev/android-release-signing.md)

```bash
# 简要：android/app/release.jks + 环境变量 KEYSTORE_PASSWORD、KEY_PASSWORD
```

## 常用开发命令

```bash
flutter analyze          # 前端静态检查
flutter test             # 前端测试
cd backend && make gen   # 重新生成 proto HTTP 代码与 openapi.yaml
cd backend && make build
cd backend && go test ./...
```

## 许可证

MIT License

## 贡献

欢迎提交 Pull Request。请先阅读 [AGENTS.md](AGENTS.md) 与 [code_review.md](code_review.md)。

---

# Moe Social (English)

A **Flutter** client plus **Go / Kratos** backend for a composite social product: cute-style social feed, AI agents / tavern-style chat, virtual avatars and VIP commerce, and an experimental **AutoGLM** automation stack. Targets Android, iOS, Web, Windows, macOS, and Linux.

**Roadmap:** [docs/product/项目开发总览与当前优先级-2026-05-18.md](docs/product/项目开发总览与当前优先级-2026-05-18.md) · **Repo guidelines:** [AGENTS.md](AGENTS.md)

## Implemented areas

- **Auth:** email, Feishu OAuth, WeChat OAuth, profile & QR
- **Social:** feed, posts, comments, likes, topics, follow/friends, DMs, WebSocket, voice calls
- **Growth & commerce:** check-in, levels, achievements, wallet, VIP, gacha, inventory
- **AI:** agents, chat, lorebooks, memory manager, provider profiles; **AutoGLM** subsystem
- **Other:** cloud gallery, scan, mini-games, in-app updates, static site under `website/official/`

## Quick start

```bash
flutter pub get
flutter run
```

Configure API base URL in `lib/utils/config.dart`. Backend: see [backend/README.md](backend/README.md). Docs index: [docs/README.md](docs/README.md).

## License

MIT License — contributions welcome via Pull Request.
