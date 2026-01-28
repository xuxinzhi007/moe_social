## 全局规则

### 沟通与工作流

- 始终使用中文回复（除非用户明确要求使用其他语言）。
- 工作流遵循：调研 -> 思考 -> 计划 -> 执行 -> 复盘；在写代码前先给出可执行的计划步骤。

### 项目技术栈

- 前端：Flutter/Dart（依赖见 `pubspec.yaml`，Lint 见 `analysis_options.yaml`）。
- 后端：Go + go-zero（代码在 `backend/`，REST + gRPC）。
- Android：Gradle Kotlin DSL；CI 使用 JDK 17（见 `.github/workflows/flutter-release.yml`）。

### 目录与分层约定

Flutter（默认约定）
- `lib/models/`：数据模型（`fromJson/toJson`）。
- `lib/services/`：API/网络访问与数据源适配（避免写 UI 逻辑）。
- `lib/providers/`：Provider 状态管理（复杂逻辑避免 `setState`）。
- `lib/widgets/`：可复用 UI 组件（优先复用现有组件）。
- `lib/utils/`：工具、校验、错误处理。

Go(go-zero)
- 严格按 `api -> handler -> logic -> svc -> model` 分层；业务逻辑只写在 `internal/logic`。

### UI/UX（Moe Social Design Language）

- 风格：梦幻、柔和、圆角、可爱（避免硬朗/工业风）。
- 色板（默认）：主色 `#7F7FD5`，辅色 `#86A8E7`，点缀 `#91EAE4`，背景 `#F5F7FA`（避免纯白大底）。
- 组件：按钮圆角（`StadiumBorder` 或 `BorderRadius.circular(20+)`）；卡片白底圆角（常用 `BorderRadius.circular(24)`）+ 轻阴影；输入框优先 filled + 圆角。
- 动画：页面内容入场优先使用 `FadeInUp`（见 `lib/widgets/fade_in_up.dart`）。
- 详细规范参考：`UI设计规范.md` 与 `.cursorrules`。

### 编码与命名

- 命名：文件 `snake_case`；类 `PascalCase`；变量/方法 `camelCase`。
- 错误处理：禁止空 `catch`；异常必须有日志或用户可感知反馈；优先复用项目现有的错误处理工具（如 `ErrorHandler`）。
- 代码注释：只在“非显而易见”的逻辑处添加简短注释，避免无意义注释。

### 生成代码与一致性

- 修改 `backend/api/super.api` 或 `backend/rpc/super.proto` 后，必须运行 goctl/脚本重新生成，保证生成代码与定义一致：
  - RPC：`cd backend && bash generate_rpc.sh`
  - API：`cd backend/api && bash generate_api.sh`

### 安全与仓库卫生（强制）

- 严禁提交敏感信息：密钥/证书/token/生产配置、Android `*.jks`、真实密码。
- 配置以示例模板形式提供（例如 `*.example.yaml` / `.env.example`），真实值放本地或 CI Secrets。
- 当前仓库内已出现高风险内容：`android/app/release.jks` 与 README 中的签名口令/配置示例；后端 `backend/api/etc/super.yaml` 可能包含密钥字段。后续变更应优先做脱敏与迁移（不要在 PR/提交中继续扩散）。

### 常用命令

Flutter
- 安装依赖：`flutter pub get`
- 静态检查：`flutter analyze`
- 测试：`flutter test`
- 运行：`flutter run`

Backend
- 下载依赖：`cd backend && go mod download`
- 运行 RPC：`cd backend/rpc && go run super.go -f etc/super.yaml`
- 运行 API：`cd backend/api && go run super.go -f etc/super.yaml`
