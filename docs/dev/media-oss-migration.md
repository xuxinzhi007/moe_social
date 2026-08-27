# 用户媒体存储：Local → 阿里云 OSS

> 适用：帖子图 / 头像 / 私信图语音等 UGC（`POST /api/upload`、`GET /api/images/{key}`）。  
> App 接口路径不变；切 OSS 后读图可 302 到桶/CDN。

## 架构

| driver | 写 | 读 |
|--------|----|----|
| `local`（默认） | VPS `image.local_dir` | API 流式输出 |
| `oss` | 阿里云 OSS | 优先 OSS；未命中回退本地（迁移过渡）；默认 302 公网 URL |

对象键：`{prefix}/{userFolder}/{filename}`，与本地 `{local_dir}/{userFolder}/{filename}` 对齐。  
业务 key 仍为 `{userFolder}__{filename}`，DB 里已有相对路径 `/api/images/...` **不用改**。

## 开通 OSS（一次性）

1. 阿里云控制台创建 Bucket（建议与 VPS 同地域，如深圳）。
2. 读写权限：开发期可「公共读、私有写」；或保持私有 + `proxy_via_api: true`。
3. 创建 AccessKey（子账号只授该桶权限），**不要提交到 Git**。
4. 填 `backend/config/config.yaml`：

```yaml
image:
  driver: local          # 先保持 local，迁完再改 oss
  local_dir: "/app/data/images"
  public_base_url: "http://你的API公网"
  oss:
    endpoint: "oss-cn-shenzhen.aliyuncs.com"
    bucket: "你的桶名"
    access_key_id: ""       # 或环境变量
    access_key_secret: ""
    prefix: "media"
    public_base_url: ""     # 可选 CDN
    proxy_via_api: false
```

环境变量（推荐）：

```bash
export MOE_OSS_ACCESS_KEY_ID=...
export MOE_OSS_ACCESS_KEY_SECRET=...
```

## 迁移步骤

在 `backend/`：

```bash
# 1. 只看将要上传的文件
go run ./cmd/migrate-media-oss -conf ./config -dry-run

# 2. 上传到 OSS（不删本地）
go run ./cmd/migrate-media-oss -conf ./config

# 3. 改配置
#    image.driver: oss

# 4. 重启 moe-social，抽查 Feed / 头像 / 私信图

# 5. 确认无误后再清理本地盘（可选，建议保留一周备份）
```

## 验收

- 新上传：文件出现在 OSS `media/{userFolder}/...`
- 旧图：`/api/images/{key}` 仍可打开（302 或反代）
- `driver: oss` 但密钥错误时：启动日志会提示并 **回退 local**，避免整站挂掉

## 非目标

- Pet 静态资源 / APK / GGUF：不走本通道  
- 管理台图库：仍可扫 `local_dir`；全量迁 OSS 后可再做「管理台列 OSS」（后续）
