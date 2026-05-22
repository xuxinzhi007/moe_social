# 手机离线 GGUF 下载方案（Hugging Face 直下）

## 目标

**从模型站（Hugging Face）下载 GGUF**：手机落盘到 Documents；Web 登记后由 `llamadart` 在浏览器缓存。推理统一走 `llamadart`。  
不依赖把大文件放在你们后端服务器上。

## 架构

```text
App 内置清单 (lib/config/hf_local_model_catalog.dart)
    ↓ https://huggingface.co/{repo}/resolve/main/{file}.gguf
手机 Documents/moe_local_models/{id}.gguf
    ↓（下一步）
llamadart 加载路径或 hf:// 源推理
```

可选：后端 `GET /api/llm/local-models/catalog` 仅作**国内镜像/内网加速**，不是主路径。

## 内置推荐模型

| ID | HF Repo | 约体积 |
|----|---------|--------|
| qwen2.5-0.5b-instruct-q4 | Qwen/Qwen2.5-0.5B-Instruct-GGUF | ~400MB |
| qwen2.5-1.5b-instruct-q4 | Qwen/Qwen2.5-1.5B-Instruct-GGUF | ~1.1GB |
| smollm2-360m-instruct-q8 | HuggingFaceTB/SmolLM2-360M-Instruct-GGUF | ~380MB |

## App 入口

设置 → AI → **离线模型下载**

实现：`LocalModelStore` + `LocalModelManagerPage`

## 与建议方案对照

| 建议 | 本项目 |
|------|--------|
| 从 HF 下载，不经过自己后端 | ✅ 默认 `HfLocalModelCatalog` + HF resolve URL |
| `llm_llamacpp` `getModelStream` | ⏳ 下一步：接入包后可用同一仓库 ID 下载+推理 |
| 0.5B / 1.5B 中文 | ✅ 默认 Qwen2.5 两档 |
| Web 离线推理 | ✅ `llamadart`（实验性 WebGPU） |
| 完全离线推理 | ✅ `llamadart` |

## 推理与工具（已实现）

见 [local-llm-tools.md](./local-llm-tools.md)：已接入 `llamadart` 与记忆工具桥接。

## 后续

1. 用 `LlamaCppRepository.getModelStream` 替代手写 HF dio 下载。
2. 后端 `llama-server` 适配（在线大模型）。
3. App 内页面跳转类工具（`open_page`）。

## 后端镜像（可选）

若 HF 在国内慢，可在 `backend/data/local_models/` 放同文件，配置 `local_models.catalog`，App 会自动合并进列表并标注「服务器镜像」。
