# OpenAPI 文档与 Apifox 同步

> **更新：2026-05-29**  
> 对齐 **core-platform** 做法：契约来自 `api/**/v1/*.proto`，文档为 **OpenAPI 3.0.3** YAML。

## 产物与访问

| 项目 | 说明 |
|------|------|
| 规范版本 | **OpenAPI 3.0.3**（非 Swagger 2.0） |
| 生成文件 | `backend/openapi.yaml` |
| 契约 SSOT | `backend/api/<domain>/v1/*.proto`（含 `google.api.http`） |
| 本地 Swagger UI | `http://127.0.0.1:8888/swagger`（需 `make moe-social` 已启动） |
| 文档 URL（推荐） | `http://127.0.0.1:8888/swagger/openapi.yaml` |
| 兼容旧 URL | `http://127.0.0.1:8888/swagger/doc.json`（内容同为 yaml，供旧工具导入） |

**已废弃**：`backend/rest.swagger.json`（Swagger 2.0，goctl 生成，仅作兜底，不再维护）。

---

## 生成方法

### 前置依赖

| 工具 | 说明 |
|------|------|
| `protoc` | 系统安装；未安装时跳过 OpenAPI 生成 |
| `protoc-gen-openapi` | 首次缺失时脚本会自动 `go install` |

新机器可一次性预装全部 proto 插件：

```bash
cd backend
make init-proto-tools
```

`init-proto-tools` 包含：`protoc-gen-go`、`protoc-gen-go-grpc`、`protoc-gen-go-http`、**`protoc-gen-openapi`**。

### 日常命令

```bash
cd backend

# 推荐：改 proto 后一并生成 pb/grpc/http + openapi.yaml
make gen

# 仅重新生成 OpenAPI（不改其它产物时）
make gen-swagger
```

`make gen` 内部流程：

1. `scripts/gen/moe-proto.sh` — 各域 `*.pb.go`、`*_grpc.pb.go`、`*_http.pb.go`
2. `scripts/gen/openapi.sh` — 合并生成 `openapi.yaml`
3. `scripts/gen/moe-conf.sh` — 配置 proto
4. `scripts/gen/http-routes` — 路由表（见下方「已知问题」）

成功时终端会看到类似输出：

```text
generated backend/openapi.yaml (OpenAPI 3.0, N paths)
```

（`N` 以 `make gen` 终端输出为准；2026-05-27 约 **100+** 顶层 path，随 proto HTTP 注解增减。）

### 生成原理

与 core-platform 相同，使用 [protoc-gen-openapi](https://github.com/google/gnostic/tree/master/cmd/protoc-gen-openapi)：

```bash
protoc \
  --proto_path=. \
  --proto_path=./third_party \
  --openapi_out=fq_schema_naming=true,default_response=false:. \
  api/**/v1/*.proto
```

脚本入口：`backend/scripts/gen/openapi.sh`。

### 改 proto 后注意

1. 在 `api/<domain>/v1/*.proto` 增加或修改 `google.api.http` 注解。
2. 若 RPC 使用 `google.protobuf.Empty`，需 `import "google/protobuf/empty.proto";`。
3. 执行 `make gen` 或 `make gen-swagger`。
4. 将更新的 `openapi.yaml` 提交进 Git（与 `*.pb.go` 一并）。

### 已知问题：`make gen` 末尾可能失败

若报错：

```text
parse routes: .../fixtures/routes.go: no such file or directory
```

说明 **`gen-http-routes` 失败**，但 **OpenAPI 通常已在上一步生成成功**。Apifox 同步不受影响。

仅重新生成文档时，可只跑：

```bash
cd backend
bash scripts/gen/openapi.sh
# 或
make gen-swagger
```

修复 `gen-http-routes`（可选，改 `api/defs` 时才需要）：

```bash
cd backend
mkdir -p scripts/gen/http-routes/fixtures
git show 'c0c8d3e^:backend/api/internal/handler/routes.go' \
  > scripts/gen/http-routes/fixtures/routes.go
make gen-http-routes
```

---

## 导入 Apifox

### 方式一：导入本地文件（推荐）

1. 在仓库根目录执行 `cd backend && make gen-swagger`（或确认 `openapi.yaml` 已存在）。
2. 打开 Apifox → **项目设置** → **导入数据** → **OpenAPI**。
3. 选择文件：`backend/openapi.yaml`。
4. 导入策略建议：
   - **覆盖已有接口**：团队 SSOT 以仓库 yaml 为准时选用。
   - **智能合并**：本地有手工调试用例时选用。
5. 配置**环境变量**（见下节）。

### 方式二：URL 导入（服务已启动）

1. 启动后端：`cd backend && make moe-social`
2. Apifox → **导入** → **URL 导入**
3. 填写：

```text
http://127.0.0.1:8888/swagger/openapi.yaml
```

4. 确认导入后，在环境中把 `baseUrl` 设为 `http://127.0.0.1:8888`（或你的局域网地址）。

### Apifox 环境建议

| 变量 | 示例值 | 说明 |
|------|--------|------|
| `baseUrl` | `http://127.0.0.1:8888` | 与 Flutter `lib/utils/config.dart` 一致 |
| `token` | （登录后 Bearer） | 需鉴权接口在 Header 加 `Authorization: Bearer {{token}}` |

登录类接口在 OpenAPI 中路径为 `/api/user/login` 等；导入后可在 Apifox「前置操作」里用脚本把响应 `token` 写入环境变量。

### 与 Swagger UI 对照

浏览器打开 `http://127.0.0.1:8888/swagger`，UI 加载同源 `openapi.yaml`，可用于快速核对路径与 schema。

---

## 覆盖范围说明

| 来源 | 是否进入 `openapi.yaml` |
|------|-------------------------|
| `api/**/v1/*.proto` 中带 `google.api.http` 的路由 | ✅ |
| `httplegacy/*_compat.go` 存量 compat 路由 | ❌（未写进 proto 的不出现） |
| `api/defs/*.api`（goctl 存量） | ❌ |

当前 path 数以 `make gen` 输出为准（`grep -c '^    /' backend/openapi.yaml` 约 **100+**，2026-05-27）。  
若 Apifox 里缺少某接口，先查该接口是否已迁入 proto；未迁移的只在 compat 层生效。

---

## 相关文件

| 路径 | 作用 |
|------|------|
| `backend/openapi.yaml` | 生成产物（提交 Git） |
| `backend/scripts/gen/openapi.sh` | OpenAPI 生成脚本 |
| `backend/scripts/gen/moe-proto.sh` | proto 生成 + 调用 openapi.sh |
| `backend/internal/apilegacy/swaggerdoc/` | `/swagger` UI 与文档 HTTP 处理器 |
| `backend/Makefile` | `gen`、`gen-swagger`、`init-proto-tools` |

## 参考

- 新接口契约：[new-api-kratos.md](./new-api-kratos.md)
- 跨平台生成注意：[cross-platform-dev.md](./cross-platform-dev.md)
- core-platform 同类做法：对方仓库根目录 `openapi.yaml` + `make api`
