# App 版本发布（后端管理台）

> **速查备忘（推荐先看）**：[app-release-cheatsheet.md](./app-release-cheatsheet.md)

# 背景

客户端检查更新**不再读 GitHub Releases**，改为读后端公开接口。管理台只配置「版本元数据 + APK 下载 URL」，**不上传安装包文件**。

若未配置或未启用，App 点「检查更新」会提示：**未发现任何发布版本**。

---

## 1. 整体流程

```text
1. 推送 tag v* → GitHub Actions 构建 APK 并上传 GitHub Releases
2. CI 登录管理后台，PUT /api/admin/app-release 回写版本元数据（方案 A）
3. 客户端 GET /api/public/app-release/latest
4. 若远端 versionCode > 本地 buildNumber → 弹更新
```

手工兜底：未配置 CI Secrets 时，仍可在 moe-admin「App 版本更新」页手动登记。

| 角色 | 职责 |
|------|------|
| CI | 产出 APK；`versionCode = GITHUB_RUN_NUMBER`；回写后端 |
| 托管 | GitHub Release 直链（`…/releases/download/<tag>/app-release.apk`） |
| 管理台 | 可改 changelog / 强制更新；强制更新字段 CI 会保留已有值 |
| App | 启动静默检查 + 设置页手动检查 |

---

## 2. 管理台怎么发版

1. 登录 **moe-admin**（与当前 App 连接的同一套后端环境）。
2. 导航：**业务** → **App 版本更新**（路由 `/biz/update`）。
3. 点击 **配置首个版本** / **编辑版本**。
4. 填写并保存：

| 字段 | 说明 | 示例 |
|------|------|------|
| **版本名 versionName** | 展示用，对应 `version:` 前半段 | `1.0.1` |
| **versionCode** | 覆盖安装依据，对应 pubspec `+` 后数字，必须 **正整数** | `2`（本地是 `1.0.0+1` 时至少填 `2`） |
| **APK 下载 URL** | 完整 http(s) 直链，不以管理台上传文件 | `https://github.com/.../app-release.apk` |
| **更新说明** | changelog，显示在更新弹窗 | 修复更新检查… |
| **启用** | 关闭后客户端视为「无可用版本」 | 勾选 |
| **强制更新** | 用户不能「稍后」，必须更新 | 按需勾选 |

5. 点 **保存并生效**。无需重启后端（写库后立即对公开接口生效）。

### 推荐发版顺序（CI 自动回写）

1. 确认 GitHub Secrets 已配齐（见 §9）。
2. 推送 tag：`git tag v1.0.3 && git push origin v1.0.3`。
3. Actions 成功后：GitHub Release 有 APK，后端 `app_releases` 已启用。
4. 需要强制更新时：管理台勾选「强制更新」并保存（下次 CI 会保留该值）。
5. 用旧版 App：设置 → 关于 → 软件版本 → 检查更新。

手工发版时：仍按「构建 → 上传直链 → 管理台填写」即可。

---

## 3. 客户端如何判定「有更新」

- 接口：`GET /api/public/app-release/latest?platform=android`（**无需登录**）。
- 仅当同时满足才算有版本：
  - `available == true`
  - `apk_url` 非空
  - `version_code > 0`
  - 库中该平台配置 **enabled = true**
- 比较规则（`UpdateService.isRemoteNewerThanLocal`）：
  - 优先比 **versionCode**（远端 > 本地 → 提示更新）
  - 缺 code 时才回退比版本名字符串

本地显示 `v1.0.0+1 Dev` 时：`+1` 即 versionCode=`1`。管理台必须配置 **大于 1** 的 versionCode，才会弹出更新。

---

## 4. 相关接口（运维自检）

| 用途 | 方法 | 路径 |
|------|------|------|
| 管理台读取 | `GET` | `/api/admin/app-release?platform=android`（需管理员鉴权） |
| 管理台保存 | `PUT` | `/api/admin/app-release` |
| App 拉取 | `GET` | `/api/public/app-release/latest?platform=android` |

公开接口无可用时的典型响应：

```json
{ "available": false, "platform": "android" }
```

此时 App 文案即为「未发现任何发布版本」。

可用 curl 自检（把主机换成 App 实际连接的后端）：

```bash
curl -sS "http://<host>:8888/api/public/app-release/latest?platform=android"
```

期望有更新时大致包含：`available: true`、`version_code`、`apk_url`。

---

## 5. 数据与限制

- 表：`app_releases`（每 **platform** 一条，当前一期仅 **android**）。
- 管理台**不托管文件**；APK 需自行放在 GitHub / OSS / CDN。
- GitHub 下载链：客户端会测速镜像；OSS 等直链则直连。
- URL 校验：必须是合法 `http`/`https`。

---

## 6. 常见问题

| 现象 | 原因 | 处理 |
|------|------|------|
| 「未发现任何发布版本」 | 未配置 / 未启用 / URL 空 / versionCode≤0 | 管理台配置并勾选启用 |
| 「当前已是最新版本」 | 远端 versionCode ≤ 本地 | 提高管理台与 APK 的 versionCode |
| 能下载但装不上 | debug 与 release **签名不同**，或 versionCode 未升高 | 同签名发版；先卸载再装（Dev 包常见） |
| 管理台改了 App 仍旧 | App 连的不是这套后端 | 核对 `AppConfig` / `isProduction` 基址 |
| 强制更新关不掉 | `force_update` 已开 | 管理台取消强制并保存 |

---

## 7. 与「后端一键发布」的区别

- **App 版本更新**（本文）：给**手机 App** 侧载升级用（`/biz/update`）。
- **ReleasePage / 后端发布流水线**：偏**服务端**构建部署，**不会**写入 `app_releases`。

手机包走 `.github/workflows/flutter-release.yml`（或管理台手工登记）。

---

## 8. 影响范围与回滚

- **影响**：仅 Android 检查更新与强制更新弹窗；不影响登录等其它业务。
- **回滚**：管理台取消「启用」或把 versionCode 调回 ≤ 客户端当前值 → 客户端不再提示更新。

---

## 9. CI 回写（方案 A）

工作流：`.github/workflows/flutter-release.yml`  
在上传 APK 到 GitHub Releases 后，用管理员账号登录并调用：

`PUT /api/admin/app-release`

| 字段 | 来源 |
|------|------|
| `platform` | 固定 `android` |
| `version_name` | tag 去掉前缀 `v`（如 `v1.0.3` → `1.0.3`） |
| `version_code` | `GITHUB_RUN_NUMBER`（与 APK `--build-number` 一致） |
| `apk_url` | `https://github.com/<owner>/<repo>/releases/download/<tag>/app-release.apk` |
| `changelog` | CI 默认文案；可随后在管理台改 |
| `enabled` | `true` |
| `force_update` | **保留**库中已有值；首次默认 `false` |

### 所需 GitHub Secrets

在仓库 **Settings → Secrets and variables → Actions** 配置（与签名 Secrets 并列）：

| Secret | 说明 |
|--------|------|
| `MOE_ADMIN_API_BASE` | App 实际连接的后端根地址，如 `https://api.example.com`（无尾斜杠） |
| `MOE_ADMIN_USERNAME` | 管理台账号（建议专用只读以外的运维号，勿用超管日常密码若可拆分） |
| `MOE_ADMIN_PASSWORD` | 对应密码 |

未配置上述三项时，构建与 GitHub Release **仍会成功**，仅跳过回写（日志：`Skip sync`）。

已配置但后端离线/连不上时：Sync 步骤会失败并打警告，但因 `continue-on-error` **不阻断**整次发版；APK 仍在 GitHub Releases，可稍后后端上线后在管理台手工补登记，或再跑一次 workflow。

`MOE_ADMIN_API_BASE` 填 **App / 管理台实际用的公网 API 根地址**（例如 `https://api.example.com` 或 `http://x.x.x.x:8888`），仓库内无写死 IP；GitHub Runner 从外网访问该地址，本机 `127.0.0.1` / 内网 IP **不可用**。

签名相关 Secrets 见 [android-release-signing.md](./android-release-signing.md)。
