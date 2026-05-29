# api/ — HTTP 契约（Kratos）

**SSOT**：`api/<domain>/v1/*.proto` + `google.api.http`

```bash
cd backend && make gen
```

| 禁止 | 替代 |
|------|------|
| `api/defs/*.api`、goctl | proto + `make gen` |
| `make gen-api` | 已退役（Makefile 会报错） |

生成物：`*.pb.go`、`*_http.pb.go`、`backend/openapi.yaml`

实现：`internal/server/grpc/<domain>/` + `internal/service/<domain>/`

历史 goctl defs 快照：`scripts/archive/api-defs/` · 说明：`api/defs/RETIRED.md`
