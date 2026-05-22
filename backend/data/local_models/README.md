# 手机离线 GGUF 托管目录

将可下载的 `.gguf` 文件放在此目录，文件名需与 `backend/config/config.yaml` 中 `local_models.catalog[].filename` 一致。

示例：

```text
backend/data/local_models/qwen2.5-0.5b-instruct-q4_k_m.gguf
```

App 通过以下接口获取清单并下载到手机：

- `GET /api/llm/local-models/catalog`
- `GET /api/llm/local-models/{id}/download`（支持 `Range` 断点续传）

**请勿将大模型文件提交进 Git。** 部署时在服务器上单独拷贝或通过对象存储分发。
