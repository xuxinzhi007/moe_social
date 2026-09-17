# 飞书 OAuth 授权验证指南

本文档用于 **联调与验收** OAuth 登录。总览与配置说明见 [飞书通知与绑定](飞书通知与绑定.md)。

> **协议已升级（2026-09）**：授权码不再出现在回跳 URL 上。新流程是 PKCE + 一次性 ticket：
> 客户端生成 `code_verifier` 并本地保管 → 用 `code_challenge` 与 `return_url` 换取服务端 `state` →
> 回调 302 只带 `oauth_ticket` + `oauth_state` → 登录时出示 `ticket` + `code_verifier`。
> **旧的 `?state=<回跳地址>` 与 `POST /login {"code": ...}` 通路已关闭**，前后端必须一起更新；
> 旧客户端授权会明确失败，而不是继续暴露开放重定向。

---

## 验证前准备（清单）

在开始前逐项打勾：

- [ ] 飞书开放平台已创建自建应用，并拿到 `app_id` / `app_secret`
- [ ] 开放平台 **安全设置 → 重定向 URL** 已添加（与下文 `redirect_uri` 字符级一致）
- [ ] `backend/config/config.yaml` 中 `feishu.enabled: true`，且 `redirect_uri`、`oauth_scope` 已填
- [ ] **`oauth.allowed_return_urls` 已包含本次要用的回跳地址**（App 深链默认已登记；Web 页面地址需运维显式追加）
- [ ] API 服务已启动（默认 `:8888`）；**启动后不要再重启**，授权事务在进程内存里，重启即全部失效
- [ ] **Web**：`redirect_uri` 使用本机可访问地址（如 `http://127.0.0.1:8888/api/auth/feishu/callback`）
- [ ] **真机 App**：`redirect_uri` 与 `lib/utils/config.dart` 的 `ApiEnvConfig.productionUrl` 指向同一台 API（如 `http://47.106.175.49:8888/api/auth/feishu/callback`）；真机走 online 需 `isProduction: true`
- [ ] Flutter 已 `flutter pub get`（含 `app_links`）；修改深链配置后已 **重新安装 App**（非仅热重载）

---

## 配置对照表

| 检查项 | Web（Chrome） | 真机 App |
|--------|---------------|----------|
| 运行方式 | `flutter run -d chrome` | `flutter run` 选 iOS/Android 设备 |
| `ApiEnvConfig`（`lib/utils/config.dart`） | `developmentUrl` 可与 API 一致 | `productionUrl` **必须**能访问公网/局域网 API，且 `isProduction: true` |
| `redirect_uri` 示例 | `http://127.0.0.1:8888/api/auth/feishu/callback` | `http://<API主机>:8888/api/auth/feishu/callback` |
| `return_url`（客户端发起时传） | 当前页地址（去 query/fragment），如 `http://127.0.0.1:8080/` | `moesocial://feishu/oauth` |
| `state` | **服务端生成并下发**，客户端只负责记下来核对 | 同左 |
| 本地事务存储 | sessionStorage（同一标签页） | 系统安全存储（Keychain / EncryptedSharedPreferences） |
| 授权打开方式 | 浏览器整页跳转 | 飞书 App（AppLink）；打不开则回落 App 内 WebView |
| 回跳参数名 | `?oauth_ticket=...&oauth_state=...` | 深链 `moesocial://feishu/oauth?oauth_ticket=...&oauth_state=...` |
| 未装飞书 | 浏览器仍可扫码/登录 | 回落 App 内 WebView 授权 |

---

## 一、后端接口冒烟

### 1. 获取授权 URL

`code_challenge` = `BASE64URL(SHA256(code_verifier))`，无填充，43 字符。下面用 **RFC 7636 附录 B 的公开向量**，
所以 verifier 与 challenge 是已知配对，可直接复制：

```
verifier  = dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
challenge = E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
```

```bash
# App 场景（return_url 已默认在白名单里，开箱可用）
curl -s -G "http://127.0.0.1:8888/api/auth/feishu/authorize-url" \
  --data-urlencode "return_url=moesocial://feishu/oauth" \
  --data-urlencode "code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM" | jq .
```

期望：

```json
{
  "code": 200,
  "success": true,
  "message": "操作成功",
  "data": {
    "authorize_url": "https://open.feishu.cn/open-apis/authen/v1/authorize?app_id=...&redirect_uri=...&state=<43字符>",
    "state": "<43字符 base64url，服务端生成>"
  }
}
```

`data.state` 必须与 `authorize_url` query 里的 `state` 一致；`redirect_uri` 必须等于 `feishu.redirect_uri`。

> Web 场景把 `return_url` 换成实际页面地址（如 `http://127.0.0.1:8080/`）——**前提是它已登记进 `oauth.allowed_return_urls`**。

### 2. 公开配置

```bash
curl -s "http://127.0.0.1:8888/api/auth/feishu/public-config" | jq .
```

期望：`enabled` 等与配置一致；若配置了 `enterprise_invite_url` 应出现在响应中。

### 3. 负向冒烟（不需要真实飞书账号，建议每次都跑）

这几条是本次安全修复的护栏，**期望全部被拒**：

> **前置条件**：`feishu.enabled: true`。代码里「飞书未启用」的检查排在所有护栏之前
> （`internal/biz/user/oauth_feishu.go:76`、`:30`），未启用时 a~d 都会先返回 `oauth disabled`，
> 而不是各自的护栏文案 —— 那不代表护栏失效，只是没走到。

```bash
# a) 回跳地址不在白名单 → 拒绝（旧协议下这里会 302 到任意外部站点）
curl -s -G "http://127.0.0.1:8888/api/auth/feishu/authorize-url" \
  --data-urlencode "return_url=https://evil.example.com/steal" \
  --data-urlencode "code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM" | jq -c '{success, message}'
# 期望：success=false，message 含「回跳地址未被服务端信任」

# b) challenge 形状不对（长度/字符集） → 拒绝
curl -s -G "http://127.0.0.1:8888/api/auth/feishu/authorize-url" \
  --data-urlencode "return_url=moesocial://feishu/oauth" \
  --data-urlencode "code_challenge=tooshort" | jq -c '{success, message}'
# 期望：success=false，message 含「授权参数不合法」

# c) 旧的 code-only 登录通路 → 拒绝
curl -s -X POST "http://127.0.0.1:8888/api/auth/feishu/login" \
  -H "Content-Type: application/json" \
  -d '{"code":"any_intercepted_code"}' | jq -c '{success, message}'
# 期望：success=false，message 含「登录方式已升级，请更新 App 后重试」

# d) 伪造 / 过期 / 重放的 ticket → 拒绝
curl -s -X POST "http://127.0.0.1:8888/api/auth/feishu/login" \
  -H "Content-Type: application/json" \
  -d '{"ticket":"never-issued","code_verifier":"dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"}' | jq -c '{success, message}'
# 期望：success=false，message 含「授权已失效，请重新登录」

# e) 回调携带篡改 / 陌生 state → 不 302 到任何外部地址
curl -s -i "http://127.0.0.1:8888/api/auth/feishu/callback?code=x&state=https%3A%2F%2Fevil.example.com" | head -1
# 期望：不是 3xx 到 evil.example.com

# f) 旧字段 state 被完全忽略（传了也不当回跳地址用）
curl -s -G "http://127.0.0.1:8888/api/auth/feishu/authorize-url" \
  --data-urlencode "state=https://evil.example.com/steal" \
  --data-urlencode "return_url=moesocial://feishu/oauth" \
  --data-urlencode "code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM" \
  | jq -r '.data.authorize_url' | grep -c "evil.example.com"
# 期望：0
```

### 4. 用 ticket 登录（需先完成一次真实授权）

`ticket` 只能从回调 302 的 `oauth_ticket` 拿到，**无法凭空构造**，因此这一步必须在真实浏览器 / 真机里走完
第二、三节的流程；纯 curl 只能验证到上面第 1、3 步。

```bash
curl -s -X POST "http://127.0.0.1:8888/api/auth/feishu/login" \
  -H "Content-Type: application/json" \
  -d '{"ticket":"<回调带回的 oauth_ticket>","code_verifier":"<发起时本地保管的 verifier>"}' | jq .
```

期望：返回 token 与用户信息；`feishu_bound` 等为 true（视账号而定）。

> `ticket` 一次性、默认 **60 秒**有效（`oauth.ticket_ttl_seconds`），用过即废。
> 授权事务（`state`）默认 **600 秒**（`oauth.auth_ttl_seconds`）。
> 同一个 ticket 重复提交第二次必须失败 —— 这正是要验的重放护栏。

---

## 二、Web 端验证（Chrome）

1. 确认 `redirect_uri` 为 `127.0.0.1`（或你本机 API 地址），且飞书后台已登记。
2. **确认当前页面地址已登记进 `oauth.allowed_return_urls`**（否则第 3 步就会 Toast「无法发起飞书授权：回跳地址未被服务端信任…」）。
3. 启动 API + `flutter run -d chrome`，打开登录页。
4. 点击 **飞书登录** → 应跳转到飞书授权页（非 App 内 WebView）。
5. 登录并同意授权 → 浏览器应回到 Moe 登录页，地址栏短暂出现 `?oauth_ticket=...&oauth_state=...`（随后被前端清掉）。
6. 页面出现 loading → 成功进入首页，Toast「飞书登录成功」。
7. **刷新页面**：地址栏不应再残留 OAuth 参数，也不应重复触发登录。

**失败排查**

| 现象 | 可能原因 |
|------|----------|
| 点飞书登录即 Toast「无法发起飞书授权：回跳地址未被服务端信任…」 | 当前页面地址没登记进 `oauth.allowed_return_urls`；或登记值与实际地址不是字符级一致（端口、末尾 `/` 都算） |
| Toast「无法发起飞书授权：…」其它原因 | API 未启动；`feishu.enabled: false`；`code_challenge` 生成失败 |
| 授权后回到登录页但 Toast「未找到本次授权记录，请重新登录」 | 授权是在**别的标签页**发起的（sessionStorage 不跨标签页）；或事务已过 600 秒；或中途重启了后端 |
| 授权后白屏 / 地址栏无 `oauth_ticket` | `redirect_uri` 未在飞书后台配置；或后端回调报错（看 API 日志） |
| `oauth_ticket` 有但登录失败 | ticket 已过 60 秒或已被消费；本地 verifier 与发起时的 challenge 不配对；后端 `app_secret` 错误 |
| 同一次授权点两次登录 | ticket 一次性，第二次必然「授权已失效」—— 属预期，重新发起即可 |

---

## 三、移动端验证（真机 App）

> **不要用 Chrome 测 App 流程**。Chrome 走 Web 分支，不会检测飞书安装、也不会走深链。

1. 将 `config.yaml` 的 `redirect_uri` 改为真机可访问的 API（与 `AppConfig.productionUrl` 一致）。
2. 飞书开放平台重定向 URL 同步修改。
3. 确认 `oauth.allowed_return_urls` 含 `moesocial://feishu/oauth`（默认已有）。
4. `flutter run` 安装到真机（修改 `AndroidManifest` / `Info.plist` 后建议完整重装）。
5. 手机已安装 **飞书**（包名 Android：`com.ss.android.lark`）。
6. 登录页点击 **飞书登录**：
   - 已装飞书且 AppLink 打开成功 → 切到飞书 App 内授权页，Moe 侧 Toast「请在飞书中完成授权…」
   - 未装飞书 / AppLink 打不开 → 回落 App 内 WebView 授权页
7. 授权完成 → 应自动回到 Moe Social（深链 `moesocial://feishu/oauth?oauth_ticket=...&oauth_state=...`）。
8. 登录页 loading → 进入首页。

**失败排查**

| 现象 | 可能原因 |
|------|----------|
| 提示未安装但已装飞书 | Android：未声明 `queries` 包名；需重装 App。iOS：未配置 `LSApplicationQueriesSchemes` |
| 授权后停在飞书 / 浏览器 | 后端未 302 到 `moesocial://...`；检查发起时传的 `return_url` 是否精确等于白名单条目 |
| 回到 App 但 Toast「未找到本次授权记录」 | 深链是**上一次**授权留下的（本地事务已清除）；或 App 进程被系统回收导致安全存储记录丢失；重新点一次飞书登录即可 |
| 回到 App 但未登录且无提示 | 深链未注册；`app_links` 未收到 URI；登录页未在栈顶 |
| WebView 里授权完但没回到 App | WebView 只认精确命中 `return_url` 的那一跳；检查深链常量与白名单是否一致 |
| 飞书内打不开授权 | `redirect_uri` 手机访问不到（仍用 127.0.0.1）；AppLink 被拦截 |
| 回调 404 | API 地址与 `redirect_uri` 主机不一致 |

### 手动验证深链（可选）

Android（需已安装 debug 包）：

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "moesocial://feishu/oauth?oauth_ticket=fake_ticket&oauth_state=fake_state"
```

**期望（与旧文档相反）**：唤起 App，登录页 **拒绝** 这次回跳并提示「未找到本次授权记录，请重新登录」。
因为本地没有与 `fake_state` 配对的事务 —— 这正是 fail-closed 护栏：陌生深链不能驱动登录。
能弹这条提示就说明深链通路 OK。

> 旧文档写的「用假 code 调后端、失败属正常」已不适用：新协议下客户端根本不会把陌生票据发出去。

---

## 四、端到端时序（App）

```
用户点击「飞书登录」
    → 本地生成 code_verifier（不出网）
    → GET /api/auth/feishu/authorize-url?return_url=moesocial://feishu/oauth&code_challenge=S256(verifier)
    → 服务端建授权事务，返回 { authorize_url, state }
    → 本地安全存储记下 { provider, state, verifier, return_url, 过期时间 }
    → 检测飞书已安装
    → AppLink 打开：https://applink.feishu.cn/client/web_url/open?url=<encode(authorize_url)>
用户在飞书内同意授权
    → 飞书 GET {redirect_uri}?code=xxx&state=<服务端 state>
    → 后端原子消费 state，把 code 封存进一次性 ticket
    → 后端 302 Location: moesocial://feishu/oauth?oauth_ticket=xxx&oauth_state=<state>
    → app_links 回调登录页
    → 按 state 认领本地事务，取回 verifier
    → POST /api/auth/feishu/login { "ticket": "xxx", "code_verifier": "..." }
    → 服务端核验 S256(verifier) == challenge、原子消费 ticket、用 code 换飞书 token
    → 清除本地事务 → 进入首页
```

**两条不变量**（验收时按这两条判断有没有退化）：

1. 授权码 `code` 从不出现在回跳 URL、浏览器历史或 Referer 里。
2. `code_verifier` 从不出网，也从不进回跳 URL；服务端只存 challenge。

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
allowed_return_urls 中本次使用的条目：
飞书应用 app_id（后四位即可）：

[ ] authorize-url 正常返回 { authorize_url, state }，两处 state 一致
[ ] 负向冒烟 a~f 全部按期望被拒
[ ] Web 回跳 oauth_ticket + oauth_state + 登录成功
[ ] Web 刷新后地址栏无残留、不重复登录
[ ] App 唤起飞书 + 深链回跳 + 登录成功
[ ] App WebView 回落路径可用（未装飞书时）
[ ] 陌生深链被拒（fail-closed 提示）
[ ] 同一 ticket 重放被拒
[ ] 后端重启后旧授权失效、需重新发起
[ ] 测试卡片发送成功（可选）

未覆盖项（如实填写，不要用单测冒充）：
备注：
```

---

## 相关文档

- [飞书通知与绑定](飞书通知与绑定.md) — 配置、接口、代码索引
- [API 调试指南](API调试指南.md)
- [Android 真机调试说明](Android真机调试说明.md)
- RFC 7636（PKCE）— 附录 B 的公开测试向量已用于 `test/utils/oauth_pkce_test.dart` 与后端 `internal/oauthflow` 用例，两侧共用同一锚点
