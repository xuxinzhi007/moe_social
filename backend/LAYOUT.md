# Backend 布局（Kratos 生产）

> **更新：2026-09-11**（补 `pkg/` 层与 `internal/platform/` 漏列的 6 个子目录；配置读取统一到 `pkg/conf`）  
> SSOT：[docs/dev/kratos-migration.md](../docs/dev/kratos-migration.md) · 状态：[docs/dev/kratos-migration-status.md](../docs/dev/kratos-migration-status.md)

## 运行

```bash
make moe-social    # 单进程 Kratos HTTP :8888
make gen           # 固定工具链生成 proto pb/grpc/http + openapi.yaml
make check-gen     # 临时生成，只读比较当前工作树的产物路径和内容

# 指定配置文件（-f 默认值即 config/config.yaml）
go run ./cmd/moe-social -f config/config.yaml
```

> `-f` 是**进程级唯一权威**：全仓已无第二处硬编码 searchDirs 的 `viper.New()`（第九批清零），
> 指到哪份配置就全程读哪份。排查「配置改了没生效」时先用它排除读错文件。
> ⚠️ flag 名是 `-f`，**不是** `-conf`（`-conf` 只在 `cmd/migrate-media-oss` 里存在）。

---

## 目录结构

```text
cmd/moe-social/
config/config.yaml
openapi.yaml                         # make gen 产出

api/<domain>/v1/*.proto
api/<domain>/v1/*.{pb,grpc.pb,http.pb}.go

internal/biz/<domain>/
internal/data/<domain>/
internal/service/<domain>/          # {domain}.go + {domain}_{feature}.go

internal/server/
  http.go                            # NewHTTPServer（唯一装配入口）
  http_proto.go                      # Register*HTTPServer
  http_docs.go                       # /swagger
  protohttp/<domain>/                # {domain}.go + {domain}_{feature}.go
  transport/                         # OAuth / WS / SSE（非 JSON）

internal/platform/
  svc/                               # ServiceContext
  wiring/                            # 启动装配（含 config_override.go：把 config.yaml 合并进 API 片段）
  bootstrap/                         # 成就钩子、Bot / Dream 调度
  moesocial/                         # 生产启动（run.go → run_http_only.go）
  moewiring/                         # 19 个 <domain>_api_in_process 开关的薄封装，判定下沉到 pkg/conf
  apiconfig/                         # API 片段配置结构体（json/yaml 驼峰 tag；原 apilegacy/config）
  apicomm/                           # HTTP/JWT/LLM 辅助（原 apilegacy/common）
  appdb/                             # GORM 连接
  yamlconf/                          # 按路径加载 YAML 片段（-f-api → api/etc/moe.yaml），不读 config.yaml
  moelog/ · chatdelivery/ · socialhook/

pkg/                                 # 可被 internal 与 cmd 复用的领域无关层
  conf/                              # ★ 配置读取 SSOT（49 个反向依赖）
    load.go                          #   Get() 懒加载+缓存；Load() 带重试并返回 error；LoadFile/Reload/IsSet/Path/Err
    config.go                        #   mapstructure 镜像；文件头列明「已知但故意不进 struct」的死键
    derive.go                        #   环境变量覆盖 + 历史键回退 + 「未设置即继承」语义（inheritBool）
  llminference/                      # Ollama / OpenAI 兼容客户端、ConfigFrom、ResolveAPIStyle
  moe/                               # brain · core · flowexec · port · postpulse · runtime · tools · toolaudit
  achievement/ · calendar/ · handdraw/ · level/ · processmem/

utils/                               # 跨层小工具（private_message.go、auth_jwt_config.go、admin_runtime_config.go…）
model/                               # GORM 模型
deploy/                              # 部署脚本与 deploy-agent 配置
internal/legacy/types/               # OAuth/SSE 类型（待 proto 化）

third_party/google/api/
```

> **新增一个配置项要改哪里**：`pkg/conf/config.go` 加字段（`mapstructure` tag）→ `pkg/conf/derive.go` 加一个导出函数
> （环境变量覆盖与历史键回退都写在这里）→ 业务侧调该函数。**不要**在业务层 `viper.New()`，也不要拼 `"<段>.<子键>"` 字符串。
> 注意 `apiconfig` 用的是 `json`/`yaml` 驼峰 tag，viper 的 `Unmarshal` 只认 `mapstructure`，两者不可互换。

---

## Service / protohttp 文件命名

| 文件 | 职责 |
|------|------|
| `{domain}.go` | `AppService` / `Server` 结构体 + `New()` |
| `{domain}_{feature}.go` | 按功能拆分的方法（如 `user_login.go`、`admin_gift.go`） |

同一 Go 包内多文件共享类型；**目录路径不变**，外部 import 无需修改。禁止新增 `app.go`、`service.go`、域级 `server.go`。

---

## HTTP 装配顺序

```text
NewHTTPServer
  → corsFilter + jwtAuthFilter + EnvelopeResponseEncoder
  → RegisterOpsHTTP
  → RegisterProtoHTTP
  → RegisterDocsHTTP
  → RegisterTransportHTTP
```

---

## 数据流

```text
Client → :8888 → protohttp/<domain> 或 transport → service → biz → data
```
