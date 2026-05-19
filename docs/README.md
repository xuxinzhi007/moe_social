# Moe Social 文档索引

仓库内说明文档的入口。新增文档时请归入对应目录，并在本页补充链接。

## 开发与环境（`dev/`）

| 文档 | 说明 |
|------|------|
| [环境配置说明](dev/环境配置说明.md) | 运行前后端所需环境 |
| [快速调试步骤](dev/快速调试步骤.md) | 日常调试流程 |
| [Android 真机调试说明](dev/Android真机调试说明.md) | 真机连接与调试 |
| [API 调试指南](dev/API调试指南.md) | 接口调试 |
| [飞书通知与绑定](dev/飞书通知与绑定.md) | 自建应用 IM、OAuth 流程、配置与代码索引 |
| [飞书 OAuth 授权验证指南](dev/飞书OAuth授权验证指南.md) | Web / 真机分步联调与验收清单 |
| [调试闪退问题指南](dev/调试闪退问题指南.md) | 崩溃与闪退排查 |
| [打包流程](dev/打包流程.md) | 各端打包 |
| [项目名称替换说明](dev/项目名称替换说明.md) | 工程重命名注意事项 |
| [前后端对接分析报告](dev/前后端对接分析报告.md) | 接口与数据对接 |
| [前端数据模型修复说明](dev/前端数据模型修复说明.md) | 前端模型与接口对齐记录 |

## 产品与需求（`product/`）

| 文档 | 说明 |
|------|------|
| [UI 设计规范](product/UI设计规范.md) | 视觉与交互约定 |
| [IA 首屏与空状态设计](product/IA首屏与空状态设计.md) | 底栏职责、首屏与空状态、冷启动流程 |
| [AI 酒馆化改造方案](product/AI酒馆化改造方案.md) | AI 角色聊天模块的产品与实现方案 |
| [AI 酒馆 UI 体验迭代方案](product/AI酒馆UI体验迭代方案-2026-05-19.md) | 酒馆模块 UI 设计系统、分页面改造与分阶段迭代（先体验后功能） |
| [探索页重构方案](product/探索页重构方案-2026-05-19.md) | 底栏「探索」、同好/玩法 Segmented、AI 酒馆入口统一 |
| [需求文档 - 虚拟形象与表情包商店](product/需求文档-虚拟形象系统和萌系表情包商店.md) | 功能需求 |
| [需求可行性分析报告](product/需求可行性分析报告.md) | 可行性结论 |
| [项目开发总览与当前优先级](product/项目开发总览与当前优先级-2026-05-18.md) | 当前已完成、缺口、偏离风险与下一步优先级 |
| [项目现状盘点与差距分析](product/项目现状盘点与差距分析-2026-05-18.md) | 当前实现、差距、偏离与优先级建议 |
| [技术建议报告](product/技术建议报告.md) | 技术方向建议 |
| [头像框与奖池配置操作流程](product/头像框与奖池配置操作流程.md) | 运营配置说明 |
| [签到等级管理后台系统实施文档](product/签到等级管理后台系统实施文档.md) | 签到/等级后台 |

## 功能与迭代（`features/`）

| 文档 | 说明 |
|------|------|
| [NEW_FEATURES_GUIDE](features/NEW_FEATURES_GUIDE.md) | 新功能使用说明 |
| [FEATURES_ANALYSIS](features/FEATURES_ANALYSIS.md) | 功能点梳理与分析 |

## AutoGLM（`autoglm/`）

| 文档 | 说明 |
|------|------|
| [AutoGLM_README](autoglm/AutoGLM_README.md) | AutoGLM 技术说明 |
| [AutoGLM 系统优化方案](autoglm/AutoGLM系统优化方案.md) | 优化方案 |
| [AutoGLM 系统优化完成总结](autoglm/AutoGLM系统优化完成总结.md) | 优化落地总结 |

## 测试（`testing/`）

| 文档 | 说明 |
|------|------|
| [E2E 测试清单](testing/E2E测试清单.md) | 端到端用例清单 |
| [API 测试结果](testing/API测试结果.md) | 接口测试结果记录 |

## 规范（`guidelines/`）

| 文档 | 说明 |
|------|------|
| [项目开发规范](guidelines/项目开发规范.md) | 仓库内开发约定 |
| [Codex启动指南-后端](guidelines/Codex启动指南-后端.md) | AI/代理修改后端前的启动规范 |
| [Codex启动指南-前端](guidelines/Codex启动指南-前端.md) | AI/代理修改前端前的启动规范 |

## 规划与备忘（`planning/`）

自 `.trae/documents` 迁入的迭代计划（原目录可保留为空或继续放草稿，以本目录为准）。

| 文档 | 说明 |
|------|------|
| [Moe Social 新功能开发计划](planning/Moe%20Social%20新功能开发计划.md) | 新功能迭代计划 |
| [充值系统实现计划](planning/充值系统实现计划.md) | 充值相关实现计划 |

## 专项说明（`specs/`）

| 文档 | 说明 |
|------|------|
| [后端语音通话需求](specs/backend_voice_call_requirements.md) | 语音通话相关需求备忘 |

## 后端代码旁文档（`../backend/`）

Go 服务说明仍在 **`backend/`** 目录，与代码同址，便于对照实现：

- [backend/README.md](../backend/README.md) — 后端总览
- 其余：`架构说明.md`、`实现指南.md`、`后端实现状态.md`、`待完成事项.md`、`CORS配置说明.md` 等

## AI / Trae 技能库（仅供参考）

编辑器或 Trae 使用的技能文档位于 **`.trae/skills/moeskill/`**，与上表相互独立；其中 `docs/` 子目录为通用 Flutter/Go 开发片段，**不必**与 `docs/` 根目录合并，避免重复维护。

---

**前端页面代码结构**：屏幕类 Dart 文件已按域归在 `lib/pages/<domain>/`（如 `auth`、`feed`、`profile`、`commerce` 等），与本文档分类思路一致。
