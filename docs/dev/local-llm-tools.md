# 本机 GGUF + 工具调用（Tool Calling）

## 原理（与建议方案一致）

通过 **`llamadart`**（Web：WebGPU/CPU 桥接；原生：FFI）与内置工具定义：

1. 在 system 中声明可用工具（记忆检索/保存等）
2. 小模型（推荐 **Qwen2.5-1.5B-Instruct**）输出 JSON 形态工具调用
3. `StreamToolExecutor` 解析并执行 `LLMTool`
4. 将工具结果塞回对话，直至产生最终自然语言回复

## 项目实现

| 模块 | 作用 |
|------|------|
| `llamadart` | 加载 GGUF、`ChatSession`、内置工具循环 |
| `MoeLlmMemoryTools` | 把现有 `AiMemoryTools` 桥接为 `LLMTool` |
| `LocalLlmChatService` | 加载已安装模型、发起带工具聊天 |
| `AiChatGatewayService` | `local_gguf` Provider 分流 |
| `AiProviderProfile.builtinLocalGguf()` | 内置「本机 GGUF（离线）」，默认开启工具 |

## 使用步骤

1. **设置 → AI → 离线模型下载**：安装 `qwen2.5-1.5b-instruct-q4`（工具效果更好）
2. **模型来源**：选择 **本机 GGUF（离线）**
3. 角色卡绑定模型 ID：`qwen2.5-1.5b-instruct-q4`
4. 聊天设置里可看到「记忆工具（高级）」说明（与中转站相同工具集）

## 可用工具（与 OpenClaw 记忆一致）

- `memory_search` / `memory_get` / `memory_save`
- `memory_list` / `memory_read_daily` / `memory_delete`

## 限制

- **Web 端不支持**本机推理
- **0.5B** 工具 JSON 不稳定，仅适合纯聊天
- **页面跳转类工具**（`open_page`）尚未接入；可后续在 `MoeLlmMemoryTools` 旁增加 `MoeAppActionTools`
- 需登录后记忆工具才能访问用户记忆库

## 依赖

```yaml
llamadart: ^0.6.14
```

Web 首次对话会从 Hugging Face 拉取 GGUF 到浏览器缓存；原生端见 [llamadart 文档](https://pub.dev/packages/llamadart)。
