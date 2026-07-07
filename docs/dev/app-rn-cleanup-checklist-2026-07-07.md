# App RN 整理清单（2026-07-07）

## 目标

在 `app-rn/` 迁移继续推进期间，优先处理不会阻塞主迁移、但能明显降低后续混乱度的整理项。

## 先止血

### 1. 修复 `app-rn` 当前类型漂移

当前 `npm run typecheck` 失败，说明迁移基线还没有稳定。

- `app-rn/App.tsx`
  - 仍然依赖 `src/navigation/RootShell`
  - 但当前工作区里该文件已不存在
- `app-rn/src/features/home/HomeScreen.tsx`
  - 仍然读取 `worldSnapshot` / `wsStatus`
- `app-rn/src/features/life/LifeScreen.tsx`
  - 仍然读取 `worldSnapshot` / `wsStatus`
- `app-rn/src/store/appStore.tsx`
  - 已切到 feed/chat/ai/profile 状态模型
  - 已不再暴露 `worldSnapshot` / `wsStatus`

建议先统一一件事：

- 要么恢复 `life` 基线，把 `RootShell + worldSnapshot + wsStatus` 补回
- 要么正式切到 `home/chat/ai/profile`，同步删掉旧页面读取

在这一步完成前，不建议继续扩散新页面和新 service。

## 可以立刻做的低冲突整理

### 2. 明确 `app-rn/` 是唯一 RN 工程

根目录当前存在：

- `app-rn/package.json`
- 根目录 `package-lock.json`

但根目录没有对应的 `package.json`。这会让人误以为仓库根目录也有一套 Node 工程。

建议：

- 删除或归档根目录孤立的 `package-lock.json`
- 在根 `README.md` 里明确：
  - Flutter 主端在仓库根
  - RN 迁移工程只在 `app-rn/`
  - 管理台只在 `moe-admin/`

### 3. 给脚本目录做边界收口

当前仓库同时存在：

- `scripts/`
- `tool/`
- `tools/`
- `backend/scripts/`

这四套目录职责重叠感很强，尤其对新协作者很不友好。

建议收口规则：

- `scripts/`
  - 根仓库级启动脚本、运维辅助脚本
- `backend/scripts/gen/`
  - Kratos / proto / openapi 生成链
- `backend/scripts/archive/`
  - 历史迁移脚本，只读参考
- `tools/`
  - 保留真正独立工具链，例如训练相关工具
- `tool/`
  - 尽量迁出或并入 `scripts/` / `tools/`

优先级最高的是把 `tool/` 和 `tools/` 的职责写清楚，不然后续 RN 侧再加脚本会继续散。

### 4. 收敛设计稿与实验目录

当前根目录还有这些高噪音目录：

- `moe-social-ui-design/`
- `moe-social-app-design/`
- `go-file/`

它们不属于 Flutter 主端、Kratos 后端、`moe-admin`、`app-rn` 这四条主线中的任何一条。

建议：

- 先确认是否还在被引用
- 若仅作历史参考，统一迁到 `docs/archive/` 或 `experiments/`
- 若仍在使用，补一份各目录用途说明，避免被误当成活跃代码

## 等迁移稳定后再做

### 5. 抽公共协议层

`app-rn/src/types/*` 正在逐步建立，但 Flutter 侧已有大量模型和接口定义。等 RN 页面骨架稳定后，可以考虑：

- 把“接口字段契约”抽成文档层 SSOT
- 优先对齐 auth/feed/chat/profile/life 这几类高频结构
- 避免 Flutter / RN / admin 三端各自维护一份命名略不同的类型

注意：这一项现在不建议急着做代码级共享，否则会和迁移主线互相踩。

## 推荐执行顺序

1. 修复 `app-rn` 类型基线，确保 `npm run typecheck` 通过
2. 清掉根目录孤立 Node 痕迹
3. 给脚本目录定边界并补文档
4. 收敛设计稿/实验目录
5. 最后再做跨端协议整理

## 本次观察结论

现在最值得整理的，不是“继续拆更多文件”，而是先把以下三件事稳定住：

- `app-rn` 的导航和 store 基线
- 仓库内 Node / 脚本入口的唯一性
- 历史目录与活跃目录的边界
