# 角色聊天模型切换与派生 Modelfile

## 背景

小主机 Ollama（`llm_inference.base_url`）上已有多份模型，其中包括 `qwen3.5:9b`。角色聊天仍被收成默认基座，思考开关在请求里写死为 `think: false`，温度等采样每次请求都会覆盖模型自身参数。

本方案只改变当前用户、当前角色的聊天。服务器 `memory_model` 继续服务记忆、发帖和游戏。

## 方案

### 聊天页

- 模型列表来自实时 Ollama `/api/tags`。可见范围是主机上的基座，加上当前用户自己的派生模型。其他用户的 `moe-user-` 模型不出现。
- 选中的模型写回该角色的 `model_name`。
- 思考开关写在角色上，默认关。仅当该模型的 `capabilities` 含 `thinking` 时可打开；否则请求保持 `think: false`。
- 上下文只展示模型返回的 `context_length`。前端不改这个值，请求不传 `num_ctx`。

### 派生模型

- 保存时新建或覆盖当前角色自己的 `moe-user-...`，`FROM` 指向选中的基座。基座文件不改。
- 再次保存覆盖同一个名字，角色绑定不变。
- 普通模式：基座 + 用户编写的系统提示词。
- 高级模式：用控件调整 `PARAMETER`（温度、`top_p`、`top_k`、`presence_penalty`、`repeat_penalty`、`frequency_penalty`、`min_p`），预填基座 `/api/show` 的参数。不提供整份 Modelfile 文本框，不允许在这里改上下文。
- 采样参数在创建时写进模型。之后的聊天请求不再附带温度和 `top_p`。

### 人设

- 选基座聊天：请求继续带角色卡上的系统提示词。
- 选该角色的派生模型：只用模型里的 `SYSTEM`，请求不再插入角色卡提示词。

## 影响范围

- 契约：`GET /api/llm/models` 增加 `catalog`；`GET /api/llm/model-prompt` 增加 `parameters_json`；`POST /api/llm/chat` 增加 `think`；`POST /api/llm/agents` 增加 `parameters_json`。
- 数据：`llm_managed_models` 增加 `parameters` 列，由现有 AutoMigrate 补齐。
- 配置：`allowed_base_models` 不再充当聊天目录白名单。聊天可见模型以实时目录为准。`memory_model` 不变。
- 客户端：聊天设置里切换模型、思考开关、上下文状态和派生模型表单。

## 迁移步骤

1. 发布带新列的后端。旧行的 `parameters` 为空，行为与只写 `SYSTEM` 相同。
2. 发布 App。旧客户端仍可读 `models` 字符串列表；新客户端读 `catalog`。

## 回滚方案

- 回滚后端后，App 的 `catalog`、`think`、`parameters_json` 会被忽略或保存失败，聊天仍可走原来的 `models` 与角色卡提示词。
- 已创建的 `moe-user-` 模型留在 Ollama 上，不自动删除。回滚后把角色 `model_name` 改回基座即可继续聊天。
