# CodeGraph（开发导航图谱）

> SSOT：本文件。产物在 `moe-admin/public/dev/codegraph/`；查看器 `/ops/infra/dev/codegraph`。

## 目标

跨栈只读图谱，帮助找**落点 / 影响面 / 内容包消费链**。  
**读模型**：JSON 由扫描脚本生成，禁止当第二份手工配置源。

## 四域

| Domain | 文件 | 扫什么 |
|--------|------|--------|
| pet | `pet.json` | `moe-admin/public/pet/moe_content`、`assets/pet/moe_content`、consumers |
| admin | `admin.json` | `workspaceNav.ts`、`App.tsx`、`src/features/*` |
| backend | `backend.json` | `openapi.yaml` + `internal/{service,biz}` + `api/*` |
| flutter | `flutter.json` | `app_routes.dart`、`lib/services`、pages→service import |

## 重新生成

仓库根目录：

```bash
node scripts/codegraph/gen_all.mjs
```

或：

```bash
cd moe-admin && npm run codegraph:gen
```

生成后提交 `moe-admin/public/dev/codegraph/*.json`（离线可看，不依赖后端）。

## 查看

1. 启动管理台：`cd moe-admin && npm run dev`
2. 打开：**运维 → 开发工具 → CodeGraph**（`/ops/infra/dev/codegraph`）
3. **连线全览（默认）**：一次渲染主干节点 + 箭头连线（route→page、nav→route、domain→service…）；可勾选「密连线」「显示边文字」
4. **骨架**：只保留最高层
5. **关系探索**：围绕单点看邻居；左侧目录双击或侧栏「以此为中心探索」
6. 全览中点节点会高亮其连线，无需逐个点开才能看到结构

## Schema

```ts
{
  schemaVersion: 1
  domain: 'pet' | 'admin' | 'backend' | 'flutter'
  generatedAt: string
  nodes: { id, kind, label, summary?, weight?, ref_id?, meta? }[]
  edges: { id, source, target, relation, weight? }[]
  stats?: Record<string, number>
}
```

## 边界（不做）

- 不在 UI 里编辑节点
- 不上运行时 API 当图谱源（v1）
- 不做完整 LSP/调用图
- 不替换 Moe Brain 的 `BrainKnowledgeGraph`（那是业务记忆图）

## 脚本

```
scripts/codegraph/
  gen_all.mjs
  gen_pet.mjs
  gen_admin.mjs
  gen_backend.mjs
  gen_flutter.mjs
  lib.mjs
```
