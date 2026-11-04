# Moe Social（萌社交）

> 一个萌系心情社交 App。发帖记录心情、浏览动态、私信朋友，还有一个会记得你的 AI 伙伴。

Moe Social 面向想低压力分享日常、找同好、并希望有长期 AI 陪伴的用户。
社交是主路径，AI 是陪伴增强层 —— 不是独立工具箱。

**支持平台**：Android · iOS · Web · Windows · macOS · Linux

---

## 你会得到什么

### 记录与分享
发动态（图文 / 手绘）、评论点赞、关注话题。
心情不用组织语言，一张图配一句话也能发。

### 找到同好
关注 / 粉丝、好友请求、兴趣社区。
通知中心和云相册把互动都收在一处。

### 私信与通话
实时私信、在线状态、语音通话。
聊得来就多说两句。

### TA 的日常
AI 伙伴有独立的聊天、关系时间线和日常记录。
它会记得你说过的话，也能陪你聊很久。
多模型、角色卡广场、世界书（Lorebook）—— 想细调可以细调。

### 星辉远征
全屏营地、英雄入住、离线快进。
你不在这段时间，世界也在走。

### 成长与装扮
签到、等级、成就；钱包、充值、订单、VIP、互动礼物、背包。
主题外观、头像装扮、表情包。

---

## 关于这个仓库

这是 Moe Social 的主仓库，包含：

| 部分 | 说明 |
|------|------|
| 客户端 | Flutter（`lib/`），一套代码跑六端 |
| 后端 | Go / Kratos 单进程（`backend/`），HTTP :8888 |
| 产品官网 | 静态页（`website/official/`），可部署 Netlify |

管理台（React）已独立成仓，不在本仓库内。

---

## 开始使用

### 终端用户

从 [Releases](../../releases) 下载对应平台的安装包。Android 用户下载 APK 直接安装即可。

**iOS / 桌面端**当前需要自行构建，见下方「从源码构建」。

### 从源码构建

需要 [Flutter 3.x](https://flutter.dev/docs/get-started/install)。

```bash
flutter pub get
flutter run
```

构建发布包：

```bash
flutter build apk --release      # Android
flutter build ios --release      # iOS（需 macOS + Xcode）
flutter build web                # Web
```

API 地址在 `lib/utils/config.dart` 配置（`isProduction` / `productionUrl` / `developmentUrl`），
修改后需**完整重启** App。真机调试时 `127.0.0.1` 指向手机本机，应使用电脑局域网 IP 或线上地址。

> 各平台的环境准备、签名配置与常见问题见 [开发者入口](docs/CONTRIBUTING.md)。

---

## 参与开发

**开发者请从这里开始 → [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)**

它按「我要做什么」分流到环境搭建、后端改接口、Flutter 改页面、发版、运维等具体文档。

| 常用入口 | |
|---|---|
| 贡献规范与命令 | [AGENTS.md](AGENTS.md) |
| 文档总索引 | [docs/README.md](docs/README.md) |
| 产品定位与边界 | [docs/product/product-positioning.md](docs/product/product-positioning.md) |
| Code Review 标准 | [code_review.md](code_review.md) |

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 客户端 | Flutter 3.x、Dart、Provider、MoeTokens 设计系统 |
| 后端 | Go 1.25+、Kratos、Protocol Buffers、GORM、MySQL、JWT |
| 实时 / 媒体 | WebSocket、Agora RTC |
| 第三方 | 飞书 / 微信 OAuth、fluwx |

---

## 许可证

MIT License。贡献前请阅读 [AGENTS.md](AGENTS.md) 与 [code_review.md](code_review.md)。
