# App 发版速查（别忘了）

一页备忘：手机包怎么发、Secrets 在哪、连哪个后端、更新怎么生效。  
细节分别见文末「相关文档」。

---

## 1. 一句话流程

```text
推 tag v* → GitHub Actions 打 APK → 上传 Releases
         →（可选）CI 回写后端 app_releases
         → App 读 GET /api/public/app-release/latest → 提示更新
```

- **APK 文件**：在 GitHub Releases  
- **「有没有新版本」**：看后端库表，不看 GitHub Tag  
- 后端不在线：打包仍成功；回写失败不挡发版（可稍后管理台补登）

---

## 2. 日常发版（最短路径）

```bash
git tag v1.0.3
git push origin v1.0.3
```

然后打开：仓库 → **Actions** → **Build and Release APK**，看是否绿/黄。

| 检查项 | 在哪看 |
|--------|--------|
| APK 是否上传 | [Releases](https://github.com/xuxinzhi007/moe_social/releases) |
| 后端版本是否写上 | moe-admin → **业务** → **App 版本更新**（`/biz/update`） |
| App 能否更新 | 设置 → 关于 → 软件版本 → 检查更新 |

需要强制更新：管理台勾选「强制更新」并保存（下次 CI 会保留该勾选）。

---

## 3. GitHub Secrets（最容易忘）

**位置（网页）：**

1. 打开仓库 `xuxinzhi007/moe_social`  
2. **Settings**（仓库设置）  
3. 左侧 **Secrets and variables** → **Actions**  
4. 停留在 **Secrets** 页签 → **Repository secrets**  

不要点：Runners / GitHub Apps / Variables（Variables 不是这套）。

| Secret | 干什么 | 忘了会怎样 |
|--------|--------|------------|
| `KEYSTORE_BASE64` | 签名 jks 的 Base64 | **打不出**正式可覆盖安装的包 |
| `KEYSTORE_PASSWORD` | 密钥库密码 | 同上 |
| `KEY_PASSWORD` | 密钥密码 | 同上 |
| `MOE_ADMIN_API_BASE` | CI 要请求的后端根地址 | 包能发，**不会**自动写版本 |
| `MOE_ADMIN_USERNAME` | 管理台账号 | 同上 |
| `MOE_ADMIN_PASSWORD` | 管理台密码 | 同上 |

- Secret **创建后不能再看明文**，只能改/删重加。  
- `MOE_ADMIN_API_BASE` **不是**前端自动读的配置，要和线上一致地**手填**。  
- 推荐填法：与 Flutter `lib/utils/config.dart` 里 `productionUrl` 相同，例如：

  `http://47.106.175.49:8888`（无末尾 `/`）

- GitHub Runner 在公网，填 `127.0.0.1` / 内网 IP **无效**。  
- 未配 `MOE_ADMIN_*`：日志会有 `Skip sync`，属正常。  
- 已配但后端关机：Sync 步骤可能黄，整次发版仍算成功。

---

## 4. 前端 / 后端地址对照（别混）

| 名字 | 在哪 | 给谁用 |
|------|------|--------|
| `AppConfig.productionUrl` | `lib/utils/config.dart` | **手机 App** 连线上 API |
| `AppConfig.developmentUrl` | 同上 | **本地调试** App |
| `isProduction` | 同上 | `true` 用线上，`false` 用本地 |
| `MOE_ADMIN_API_BASE` | GitHub Secrets | **CI 回写**版本用 |
| 管理台数据环境 | moe-admin 顶栏 | 管理台连本机 / 云端 |

原则：用户装的正式包连哪台后端，CI 的 `MOE_ADMIN_API_BASE` 就应是哪台；否则「发了版但检查更新没反应」。

公开自检：

```bash
curl -sS "http://47.106.175.49:8888/api/public/app-release/latest?platform=android"
```

（主机换成你实际的 `MOE_ADMIN_API_BASE`）

---

## 5. 版本号怎么算

| 字段 | CI 怎么来 | 说明 |
|------|-----------|------|
| versionName | tag 去掉 `v`（`v1.0.3` → `1.0.3`） | 展示用 |
| versionCode | `GITHUB_RUN_NUMBER` | **比大小看这个**；每次 Actions 跑会涨 |
| apk_url | `…/releases/download/<tag>/app-release.apk` | 直链下载 |

本地 Dev 包显示 `v1.0.0+1` 时，远端 `versionCode` 必须 **大于 1** 才会提示更新。

---

## 6. 后端不在线 / 回写失败时

1. APK 已在 Releases → 发版本身 OK。  
2. 后端上线后二选一：  
   - moe-admin 手工填版本并启用；或  
   - 再跑一次 workflow / 再打一个 tag（会再试回写）。  
3. 强制更新、文案精修：始终可以在管理台改。

---

## 7. 常见坑

| 现象 | 先查 |
|------|------|
| 「未发现任何发布版本」 | 后端未启用 / 未配置 / CI 没回写成功 |
| 「已是最新」 | 远端 versionCode ≤ 手机本地 |
| 能下不能装 | 签名不一致（Dev vs Release）或 versionCode 没升高 |
| CI Sync 失败 | Secrets 错、后端关机、填了内网地址 |
| 管理台改了 App 仍旧 | App 连的不是这套后端（`isProduction` / URL） |

---

## 8. 相关文档（需要细节再点）

| 文档 | 内容 |
|------|------|
| [app-release-backend.md](./app-release-backend.md) | 接口、管理台字段、CI 方案 A 细节 |
| [android-release-signing.md](./android-release-signing.md) | 签名文件、KEYSTORE_* 怎么生成 |
| 工作流 | `.github/workflows/flutter-release.yml` |
| 前端 API 入口 | `lib/utils/config.dart` |
| 管理台页 | moe-admin → 业务 → App 版本更新 |

---

## 9. 与「后端部署」的区别（别走错页）

| 能力 | 在哪 | 干什么 |
|------|------|--------|
| **App 版本更新**（本文） | 运营 `/biz/update` | 手机安装包升级元数据 |
| **后端一键发布** | 运维 `/infra/deploy`（需 **super_admin**） | 编/传 `bin/moe-social` + Docker |
| **GitHub APK 构建** | 运维 `/infra/release`（需 **super_admin**） | 只触发 Actions，不写库 |
| Settings → Actions → **Runners** | GitHub 网页 | 自托管 Runner；**当前发版不用配** |

后端 Deploy 细节：[deploy-platform.md](./deploy-platform.md)
