# Android Release 签名配置

> 本文档含敏感信息，请勿提交到公开仓库。若仓库曾公开，请轮换 keystore 密码并评估是否更换 `release.jks`。

## 签名文件

| 项目 | 值 |
|------|-----|
| 签名文件 | `android/app/release.jks` |
| 密钥别名 (Key Alias) | `key` |
| 密钥库密码 (Store Password) | 见团队密码管理器 |
| 密钥密码 (Key Password) | 见团队密码管理器 |

本地开发/CI 通过环境变量注入，**不要**写进 `README` 或 Gradle 默认值：

```bash
export KEYSTORE_PASSWORD='你的密码'
export KEY_PASSWORD='你的密码'
```

## GitHub Actions Secrets

在 **Settings → Secrets and variables → Actions** 中配置：

| Secret Name | 说明 |
|-------------|------|
| `KEYSTORE_BASE64` | `release.jks` 的 Base64 |
| `KEYSTORE_PASSWORD` | 密钥库密码 |
| `KEY_PASSWORD` | 密钥密码 |
| `MOE_ADMIN_API_BASE` | （可选）CI 回写 App 版本的后端根 URL |
| `MOE_ADMIN_USERNAME` | （可选）管理台登录用户 |
| `MOE_ADMIN_PASSWORD` | （可选）管理台登录密码 |

后三项用于发版后自动 `PUT /api/admin/app-release`，详见 [app-release-backend.md](./app-release-backend.md) §9。未配置则只发 GitHub Release，不回写后端。

生成 `KEYSTORE_BASE64`（PowerShell）：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android/app/release.jks"))
```

Linux/macOS：

```bash
base64 -i android/app/release.jks | tr -d '\n'
```

## 新电脑还原 keystore

1. 将 `release.jks` 复制到 `android/app/`，或
2. 从 Secret 还原：
   ```bash
   echo "$KEYSTORE_BASE64" | base64 -d > android/app/release.jks
   ```

## 重新生成签名（慎用）

```bash
keytool -genkey -v -keystore android/app/release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key \
  -storepass "$KEYSTORE_PASSWORD" -keypass "$KEY_PASSWORD" \
  -dname "CN=MoeSocial, OU=MoeSocial, O=MoeSocial, L=Shanghai, S=Shanghai, C=CN"
```

重新生成后用户需卸载旧版才能安装，除非沿用同一 keystore。

## Gradle

`android/app/build.gradle.kts` 从环境变量读取密码；未设置时构建 Release 会失败，属预期行为。
