# 飞书 OAuth 授权验证指南

本文档用于 **联调与验收** OAuth 登录。总览与配置说明见 [飞书通知与绑定](飞书通知与绑定.md)。

---

## 验证前准备（清单）

在开始前逐项打勾：

- [ ] 飞书开放平台已创建自建应用，并拿到 `app_id` / `app_secret`
- [ ] 开放平台 **安全设置 → 重定向 URL** 已添加（与下文 `redirect_uri` 字符级一致）
- [ ] `backend/config/config.yaml` 中 `feishu.enabled: true`，且 `redirect_uri`、`oauth_scope` 已填
- [ ] API 服务已启动（默认 `:8888`）
- [ ] **Web**：`redirect_uri` 使用本机可访问地址（如 `http://127.0.0.1:8888/api/auth/feishu/callback`）
- [ ] **真机 App**：`redirect_uri` 与 `lib/config/moe_api.json` 的 `api_base_url` 指向同一台 API（如 `http://47.106.175.49:8888/api/auth/feishu/callback`）
- [ ] Flutter 已 `flutter pub get`（含 `app_links`）；修改深链配置后已 **重新安装 App**（非仅热重载）

---

## 配置对照表

| 检查项 | Web（Chrome） | 真机 App |
|--------|---------------|----------|
| 运行方式 | `flutter run -d chrome` | `flutter run` 选 iOS/Android 设备 |
| `moe_api.json` | 可与 API 一致 | **必须**能访问公网/局域网 API |
| `redirect_uri` 示例 | `http://127.0.0.1:8888/api/auth/feishu/callback` | `http://<API主机>:8888/api/auth/feishu/callback` |
| OAuth `state` | 当前页 origin | `moesocial://feishu/oauth` |
| 授权打开方式 | 浏览器整页跳转 | 飞书 App（AppLink） |
| 回跳参数名 | URL 上 `feishu_code` | 深链 `moesocial://feishu/oauth?feishu_code=` |
| 未装飞书 | 浏览器仍可扫码/登录 | Toast「未安装飞书 App」，流程结束 |

---

## 一、后端接口冒烟

### 1. 获取授权 URL

```bash
# Web 场景 state 示例
curl -s "http://127.0.0.1:8888/api/auth/feishu/authorize-url?state=http%3A%2F%2Flocalhost%3A8080%2F" | jq .

# App 场景 state 示例
curl -s "http://127.0.0.1:8888/api/auth/feishu/authorize-url?state=moesocial%3A%2F%2Ffeishu%2Foauth" | jq .
```

期望：返回 JSON 含 `url`，且 `url` 以 `https://open.feishu.cn/open-apis/authen/v1/authorize` 开头，query 中含 `app_id`、`redirect_uri`、`state`。

### 2. 公开配置

```bash
curl -s "http://127.0.0.1:8888/api/auth/feishu/public-config" | jq .
```

期望：`enabled` 等与配置一致；若配置了 `enterprise_invite_url` 应出现在响应中。

### 3. 用 code 登录（需先完成一次真实授权拿到 code）

```bash
curl -s -X POST "http://127.0.0.1:8888/api/auth/feishu/login" \
  -H "Content-Type: application/json" \
  -d '{"code":"<飞书返回的 code，5 分钟内有效>"}' | jq .
```

期望：返回 token 与用户信息；`feishu_bound` 等为 true（视账号而定）。

> `code` 一次性、约 5 分钟有效；不要用旧 code 重复测。

---

## 二、Web 端验证（Chrome）

1. 确认 `redirect_uri` 为 `127.0.0.1`（或你本机 API 地址），且飞书后台已登记。
2. 启动 API + `flutter run -d chrome`，打开登录页。
3. 点击 **飞书登录** → 应跳转到飞书授权页（非 App 内 WebView）。
4. 登录并同意授权 → 浏览器应回到 Moe 登录页，地址栏含 `?feishu_code=...`（随后会被前端清掉）。
5. 页面出现 loading → 成功进入首页，Toast「飞书登录成功」。

**失败排查**

| 现象 | 可能原因 |
|------|----------|
| 授权后白屏 / 无 `feishu_code` | `state` 与当前 origin 不一致；或 `redirect_uri` 未在飞书后台配置 |
| `feishu_code` 有但登录失败 | code 过期；后端 `app_secret` 错误；`redirect_uri` 与换 token 时不一致 |
| 点了飞书没反应 | API 未启动；`/authorize-url` 报错 |

---

## 三、移动端验证（真机 App）

> **不要用 Chrome 测 App 流程**。Chrome 走 Web 分支，不会检测飞书安装、也不会走深链。

1. 将 `config.yaml` 的 `redirect_uri` 改为真机可访问的 API（与 `moe_api.json` 一致）。
2. 飞书开放平台重定向 URL 同步修改。
3. `flutter run` 安装到真机（修改 `AndroidManifest` / `Info.plist` 后建议完整重装）。
4. 手机已安装 **飞书**（包名 Android：`com.ss.android.lark`）。
5. 登录页点击 **飞书登录**：
   - 未装飞书 → 仅 Toast「未安装飞书 App」
   - 已装飞书 → 切到飞书 App 内授权页
6. 授权完成 → 应自动回到 Moe Social（深链 `moesocial://feishu/oauth?feishu_code=...`）。
7. 登录页 loading → 进入首页。

**失败排查**

| 现象 | 可能原因 |
|------|----------|
| 提示未安装但已装飞书 | Android：未声明 `queries` 包名；需重装 App。iOS：未配置 `LSApplicationQueriesSchemes` |
| 授权后停在飞书 / 浏览器 | 后端未 302 到 `moesocial://...`；检查 `state` 是否为 `moesocial://feishu/oauth` |
| 回到 App 但未登录 | 深链未注册；`app_links` 未收到 URI；登录页未在栈顶 |
| 飞书内打不开授权 | `redirect_uri` 手机访问不到（仍用 127.0.0.1）；AppLink 被拦截 |
| 回调 404 | API 地址与 `redirect_uri` 主机不一致 |

### 手动验证深链（可选）

Android（需已安装 debug 包）：

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "moesocial://feishu/oauth?feishu_code=test_code_placeholder"
```

期望：唤起 App，登录页尝试用该 code 调后端（会失败属正常，说明深链通路 OK）。

---

## 四、端到端时序（App）

```
用户点击「飞书登录」
    → 检测飞书已安装
    → GET /api/auth/feishu/authorize-url?state=moesocial://feishu/oauth
    → AppLink 打开：https://applink.feishu.cn/client/web_url/open?url=<encode(authorize_url)>
用户在飞书内同意授权
    → 飞书 GET {redirect_uri}?code=xxx&state=moesocial://feishu/oauth
    → 后端 302 Location: moesocial://feishu/oauth?feishu_code=xxx
    → app_links 回调登录页
    → POST /api/auth/feishu/login { "code": "xxx" }
    → 进入首页
```

---

## 五、设置页相关（可选）

路径：**设置 → 账号与安全 → 飞书通知**

- [ ] 已 OAuth 用户显示绑定状态 / 飞书名
- [ ] 可发送测试卡片（`POST /api/user/feishu/test-card`）
- [ ] 若配置了 `enterprise_invite_url`，可见「申请加入企业」入口

---

## 六、记录模板（验收留档）

```
日期：
环境：Web / iOS / Android
API 地址：
redirect_uri：
飞书应用 app_id（后四位即可）：

[ ] authorize-url 正常
[ ] Web 回跳 feishu_code + 登录成功
[ ] App 唤起飞书 + 深链回跳 + 登录成功
[ ] 未装飞书仅 Toast（App）
[ ] 测试卡片发送成功（可选）

备注：
```

---

## 相关文档

- [飞书通知与绑定](飞书通知与绑定.md) — 配置、接口、代码索引
- [API 调试指南](API调试指南.md)
- [Android 真机调试说明](Android真机调试说明.md)
