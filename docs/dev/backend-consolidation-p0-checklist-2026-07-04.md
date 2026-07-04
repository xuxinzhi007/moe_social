# 后端收敛 P0：完成清单

> 日期：2026-07-04
> 主文档：
> [backend-consolidation-p0-p3-2026-07-04.md](C:/Users/ZhuanZ1/Desktop/moe_social/docs/dev/backend-consolidation-p0-p3-2026-07-04.md)

## 1. P0 定义

P0 的目标不是继续补功能，而是把后端收敛工作正式立项，并建立后续 P1-P3 的统一基线。

## 2. P0 完成标准

只有同时满足以下条件，P0 才算完成：

1. 已产出正式后端收敛方案文档。
2. 已明确当前复杂度来源。
3. 已明确目标架构和 AI 主链路。
4. 已明确 P1-P3 路线。
5. 已形成模块归并表。
6. 已形成配置归并表。
7. 已形成统一术语表。
8. 已明确本轮不做项。

## 3. 当前完成状态

### 3.1 已完成

- [x] 正式方案文档：
  [backend-consolidation-p0-p3-2026-07-04.md](C:/Users/ZhuanZ1/Desktop/moe_social/docs/dev/backend-consolidation-p0-p3-2026-07-04.md)
- [x] 模块归并表：
  [backend-consolidation-p0-module-map-2026-07-04.md](C:/Users/ZhuanZ1/Desktop/moe_social/docs/dev/backend-consolidation-p0-module-map-2026-07-04.md)
- [x] 配置归并表：
  [backend-consolidation-p0-config-map-2026-07-04.md](C:/Users/ZhuanZ1/Desktop/moe_social/docs/dev/backend-consolidation-p0-config-map-2026-07-04.md)
- [x] 当前复杂度来源已归纳。
- [x] 目标架构已定义。
- [x] AI 主链路已定义。
- [x] P1-P3 路线已定义。
- [x] 统一术语表已定义。

### 3.2 未纳入 P0

- [ ] 不在 P0 做大规模代码实现重写
- [ ] 不在 P0 新增 AI 页面或零散功能
- [ ] 不在 P0 扩张运行模式和迁移期开关

说明：以上三项不是“未完成事项”，而是明确禁止项。

## 4. P0 输出物

P0 最终输出物如下：

1. [backend-consolidation-p0-p3-2026-07-04.md](C:/Users/ZhuanZ1/Desktop/moe_social/docs/dev/backend-consolidation-p0-p3-2026-07-04.md)
2. [backend-consolidation-p0-module-map-2026-07-04.md](C:/Users/ZhuanZ1/Desktop/moe_social/docs/dev/backend-consolidation-p0-module-map-2026-07-04.md)
3. [backend-consolidation-p0-config-map-2026-07-04.md](C:/Users/ZhuanZ1/Desktop/moe_social/docs/dev/backend-consolidation-p0-config-map-2026-07-04.md)
4. [backend-consolidation-p0-checklist-2026-07-04.md](C:/Users/ZhuanZ1/Desktop/moe_social/docs/dev/backend-consolidation-p0-checklist-2026-07-04.md)

## 5. 结论

以本清单为准，当前 `P0` 已完成。

下一阶段进入 `P1`，重点是：

1. `ServiceContext` 归并
2. `wire_svc.go` 分域
3. `moewiring/config.go` 配置归并
