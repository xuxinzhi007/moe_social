# 当前项目导览

这三份是 **2026-11-13** 对照代码画出的导览，方便先看清产品壳、运行结构和对象关系。

读者现在该做的事：按需要打开下面一篇。改产品边界、视觉或接口时，仍以各篇点名的 SSOT 和代码为准，不要把导览当成第二份规格。

| 稿 | Markdown | 可打开的页面 |
|----|----------|----------------|
| 设计稿 | [design.md](./design.md) | [design.html](./design.html) |
| 架构稿 | [architecture.md](./architecture.md) | [architecture.html](./architecture.html) |
| 关系稿 | [relationships.md](./relationships.md) | [relationships.html](./relationships.html) |

取证说明：data-workflow 的 `knowledge_root` / `cards_dir` 未配置，仓库里也没有 `docs/domain/`。结论来自 `docs/product/product-positioning.md`、`lib/theme/moe_tokens.dart`、`lib/app/main_shell.dart` 和 `backend/model/`。与旧文档冲突的地方，正文标了「存在冲突」。

设计稿和关系稿共用 [atlas.css](./atlas.css)。架构稿是另一类页面：一张自包含的分层架构图（深色网格、实线同步、虚线 WebSocket），不是说明卡片。打开 [architecture.html](./architecture.html)。
