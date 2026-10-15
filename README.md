# Moe Social（萌社交）

萌系心情社交产品：**Flutter 客户端 + Go/Kratos 单进程后端 + React 管理台**的单体仓库。
主路径是发帖 / Feed / 私信 / 好友；AI 伙伴（Companion）与星辉远征（Arena）是陪伴增强层。
支持 Android、iOS、Web、Windows、macOS、Linux。

> 产品定位与边界：[docs/product/product-positioning.md](docs/product/product-positioning.md) · 贡献与命令约定：[AGENTS.md](AGENTS.md)

## 功能模块

### 社交主路径
- 动态流、发帖（图文 / 手绘）、评论、点赞、话题
- 关注 / 粉丝、好友请求与好友列表
- 私信、WebSocket 实时消息、在线状态、语音通话（Agora）
- 兴趣社区、通知中心、云相册

### 账号与认证
- 邮箱注册 / 登录、验证码、找回密码
- 飞书 / 微信 OAuth 登录与绑定、JWT 会话、用户二维码

### AI 伙伴与星辉远征
- AI 伙伴聊天、关系时间线、「TA 的日常」、用户记忆管理
- 星辉远征（Arena）：全屏营地页、英雄入住、离线快进摘要
- 多模型聊天、Provider Profile、Lorebook / 世界书、角色卡广场

### 成长与商业化
- 签到、用户等级、成就系统
- 钱包、充值、订单中心、VIP 中心、互动礼物、背包

### 其他
- 静态产品官网 `website/official/`（可部署 Netlify）
- 主题 / 外观、隐私与消息保留、应用内更新检测
- AutoGLM 自动化实验（默认关闭，设置 → 高级选项）

## 技术栈

| 层级 | 技术 |
|------|------|
| 客户端 | Flutter 3.x、Dart、Provider、MoeTokens 设计系统 |
| 后端 | Go 1.25+、Kratos、Protocol Buffers、GORM、MySQL、JWT |
| 管理台 | React + Vite（`moe-admin/`） |
| 实时 / 媒体 | WebSocket、Agora RTC |
| 第三方 | 飞书 / 微信 OAuth、fluwx |

## 快速开始

### 前端

```bash
flutter pub get
flutter run
```

API 地址在 `lib/utils/config.dart` 配置（`isProduction` / `productionUrl` / `developmentUrl`），修改后需**完整重启** App。真机调试时 `127.0.0.1` 指向手机本机，应使用电脑局域网 IP 或线上地址。

### 后端（本地）

```bash
cd backend
go mod download
make gen          # 修改 api/<domain>/v1/*.proto 后重新生成
make build        # 产出 bin/moe-social（单进程）
make test         # 注意：必须走 make（已写死 CGO_ENABLED=1），裸 go test 会让 sqlite 用例静默 skip
```

Docker 二进制部署（需先 `make build`，compose 挂载 `./bin/moe-social`）：

```bash
docker compose -f docker-compose.binary.yml up -d
```

环境联调：[docs/dev/环境配置说明.md](docs/dev/环境配置说明.md) · 后端详情：`backend/README.md`

## 项目结构

```
moe_social/
├── lib/                    # Flutter 客户端
│   ├── app/                # 路由、主 Shell
│   ├── pages/              # 按域划分：feed、chat、ai、arena、commerce、community…
│   ├── services/、providers/、widgets/、models/、utils/、theme/
│   └── main.dart
├── backend/                # Go / Kratos（api/<domain>/v1/*.proto → make gen）
├── moe-admin/              # React 管理台
├── docs/                   # 文档中心 → docs/README.md
├── website/official/       # 静态产品官网
├── test/                   # Flutter 测试
└── AGENTS.md               # 仓库贡献与常用命令
```

## 文档

| 用途 | 链接 |
|------|------|
| 文档总索引 | [docs/README.md](docs/README.md) |
| 产品定位 SSOT | [docs/product/product-positioning.md](docs/product/product-positioning.md) |
| 记忆系统 SSOT | [docs/dev/用户记忆系统-OpenClaw式演进设计.md](docs/dev/用户记忆系统-OpenClaw式演进设计.md) |
| Kratos 迁移状态 | [docs/dev/kratos-migration-status.md](docs/dev/kratos-migration-status.md) |
| 部署平台 / Agent | [docs/dev/deploy-platform.md](docs/dev/deploy-platform.md) |
| 闲置功能清理记录 | [docs/dev/cleanup-2026-10-15.md](docs/dev/cleanup-2026-10-15.md) |
| Code Review | [code_review.md](code_review.md) |

## 运维部署台（Deploy Agent）

一体化运维界面：构建后端、管理 Docker、触发 GitHub APK 流水线。

```bash
cd backend
cp deploy/config.example.yaml deploy/config.yaml   # 修改 token
make deploy-agent
# 浏览器打开 http://127.0.0.1:19010/
```

详见 [docs/dev/deploy-platform.md](docs/dev/deploy-platform.md)。

## CI/CD 与自动更新

推送 `v*` Tag（如 `v1.0.3`）触发 GitHub Actions 构建 Release APK 并发布到 GitHub Releases。

```bash
git tag v1.0.3
git push origin v1.0.3
```

- 发版速查（Secrets / 流程 / 别忘清单）：[docs/dev/app-release-cheatsheet.md](docs/dev/app-release-cheatsheet.md)
- App 内更新：客户端读 `GET /api/public/app-release/latest`（CI 发版后自动回写），设置 → 常规 → 软件版本 可手动检查
- Release 签名：[docs/dev/android-release-signing.md](docs/dev/android-release-signing.md)
- 后端交叉编译 Linux：`cd backend && make build-linux`（勿用 `go env -w GOOS=linux` 改全局）

## 常用开发命令

```bash
flutter analyze          # 前端静态检查
flutter test             # 前端测试
cd backend && make gen   # 重新生成 proto 代码与 openapi.yaml
cd backend && make build
cd backend && make test
```

## 许可证

MIT License。贡献请先阅读 [AGENTS.md](AGENTS.md) 与 [code_review.md](code_review.md)。
