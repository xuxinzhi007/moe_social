# api/defs 只读镜像（归档）

本目录为 `backend/api/defs/` 的**时间点快照**，仅供灾难恢复与历史对照。

- **生产契约 SSOT**：`backend/api/<domain>/v1/*.proto` + `google.api.http`
- **活跃 defs**：仍在 `backend/api/defs/`；`make gen-api` 仍从那里读取
- **禁止**在本镜像目录直接修改后同步回生产

同步方式（维护者手动）：

```bash
cp -R backend/api/defs/. backend/scripts/archive/api-defs/
```
