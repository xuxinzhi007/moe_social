# Moe Social 产品官网

面向用户的**产品型落地页**（非技术介绍）：

- `index.html` — 页面结构
- `css/landing.css` — 样式与滚动动效
- `js/landing.js` — 视差、分镜叙事、反馈表单

含：全屏 Hero、滚动进度条、无限跑马灯、分镜故事区、Bento 功能墙、横向氛围卡片、沉浸式视觉带与内测反馈。图标使用 `app-icons/` 与 App 同源。可部署至 Netlify，并作为微信开放平台 **应用官网**。

生成图标后请执行 `scripts/generate_wechat_icons.ps1`，确保 `app-icons/app_icon_64.png` 存在后再部署。

## 部署

将 `website/official/` 拖入 [Netlify Drop](https://app.netlify.com/drop)，或关联 Git 子目录部署。

部署后把 HTTPS 根地址填到开放平台，例如：`https://moesocial.netlify.app/`

## 微信开放平台（申请微信登录）

**完整资料、表单填写、包名签名、图标与流程图** 已整理至：

👉 **[`wechat-review/申请指南.md`](./wechat-review/申请指南.md)**

快速索引：

| 需求 | 位置 |
|------|------|
| 申请说明文案、Android/iOS 怎么填 | 申请指南 §三、§七、§八 |
| 流程图截图 | `wechat-review/app-flow.html` |
| 微信图标 28 / 108 | `wechat-icons/`（脚本生成） |
| 图标生成命令 | 申请指南 §六 |

## 品牌图标（命令摘要）

```powershell
powershell -ExecutionPolicy Bypass -File website/official/scripts/generate_wechat_icons.ps1
dart run flutter_launcher_icons
```

细节与 debug/release 签名对照见申请指南。

## 修改官网文案

- 联系邮箱：`xuxinzhi19@gmail.com`（见 `index.html`）
- 上线后：将「即将上线」改为应用商店链接
- 产品与实现差距评估：[docs/product/moe-app-product-assessment.md](../../docs/product/moe-app-product-assessment.md)

## 官网意见反馈

落地页 `#join` 区块提供反馈表单，提交至 `POST /api/landing/feedback`（无需登录）。后端入库后通过 `config.yaml` 中已配置的飞书机器人通知运营邮箱。

- 生产 API：`http://47.106.175.49:8888`（见 `index.html` 内 `FEEDBACK_API`）
- 部署后端后需执行数据库迁移（`LandingFeedback` 表）
- 静态站与 API 跨域已由后端 CORS 中间件处理
- 管理查看：本地 `make deploy-agent` 后打开 `http://127.0.0.1:19010/ops/feedback`（无需 Token）
