# api/ — HTTP 契约

**SSOT**：`api/<domain>/v1/*.proto` + `google.api.http`

```bash
cd backend && make gen
```

产出：`*.pb.go`、`*_http.pb.go`、`backend/openapi.yaml`（Apifox 导入）

实现：`internal/server/protohttp/<domain>/` + `internal/service/<domain>/`
