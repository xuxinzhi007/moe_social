# AI Provider 密钥可选云端同步方案

## 背景

模型服务配置已经支持本机安全保存 API Key，但用户在更换设备或清理本地数据后需要重新输入。产品仍应保持“默认不上传密钥”的安全边界，同时为明确需要多设备使用的用户提供账号级同步。

## 方案

- API Key 默认只保存于当前设备的安全存储；Web 端沿用现有本地存储降级。
- 用户在 Provider 编辑页主动开启“同步到账号”后，才将该 Provider 的密钥写入当前登录账号。
- 服务端不把密钥写入 Provider 元数据 JSON，使用 `ai_user_configs.provider_api_keys_encrypted` 独立字段保存 AES-GCM 密文。
- `/api/ai/config` 只允许通过当前登录用户上下文读写；密钥以 JSON 字符串在 HTTPS 认证请求中返回给该用户的其他设备，用于恢复本地安全存储。
- 关闭开关或清除密钥时，服务端删除对应 Provider 的云端密钥；本机已有密钥仍可继续使用。
- 云端读取失败时不覆盖本机密钥；本地保存完成后云端同步失败需向用户明确提示。

## 影响范围

- Flutter：Provider 编辑页的密钥保存状态、云端同步开关和本地恢复逻辑；聊天页移除输入框上方重复的模型配置提示，改用顶栏状态入口。
- Backend：扩展 `llm.v1` AI 用户配置契约、`AiUserConfig` 模型和 AI 配置业务逻辑；Provider 资源 JSON 继续禁止保存密钥。
- 数据库：通过现有 AutoMigrate 为 `ai_user_configs` 增加密文字段。

## 迁移步骤

1. 设置稳定的 `MOE_AI_CONFIG_ENCRYPTION_KEY` 环境变量；未设置时开发环境兼容回退到现有 `auth.access_secret`。
2. 执行 `cd backend && make gen` 生成 Proto、HTTP 路由和 OpenAPI。
3. 执行 `cd backend && go run ./cmd/migrate`，让 AutoMigrate 增加新字段。
4. 发布 Flutter 客户端；旧客户端只会继续读写原有字段，不会看到或覆盖云端密钥。

## 回滚方案

- Flutter 回滚到只使用本机 API Key 的版本，不会删除服务端密文。
- Backend 回滚前保留新增数据库字段；旧版本忽略该字段，已保存的云端密钥不会影响本机 Provider 元数据。
- 若必须停止同步，可在客户端关闭入口并保留字段，避免因回滚造成用户本机密钥丢失。
