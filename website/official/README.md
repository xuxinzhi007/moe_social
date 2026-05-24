# Moe Social 产品官网

面向用户的完整产品落地页（`index.html`）：Hero、功能矩阵、AI/社交亮点、登录方式与内测 CTA。图标使用 `app-icons/` 与 App 同源。可部署至 Netlify，并作为微信开放平台 **应用官网**。

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
