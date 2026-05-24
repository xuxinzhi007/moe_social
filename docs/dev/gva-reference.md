# gin-vue-admin 可参考能力清单（已移出仓库）

> 上游模板已从仓库删除。需要对照 UI/交互时，见官方文档与 Demo：  
> https://www.gin-vue-admin.com · http://demo.gin-vue-admin.com

**不要**迁入 `gin-vue-admin-master/server/`（Gin + GORM）或其中的 spikes/coupons 等业务页——与 Moe go-zero 体系无关。

## 值得在 Moe Admin（`moe-admin/`）借鉴的

| GVA 能力 | Moe 对应规划 | 说明 |
|----------|--------------|------|
| 登录页 + 侧栏布局 | ✅ 已有 React 浅色壳 | 参考布局即可，不必换 Vue |
| 工作台统计卡片 | ✅ `DashboardPage` | 继续补业务指标 |
| 动态菜单 + 角色可见 | P1 `admin_menu` 表 | 现为 `menu.ts` 静态树 |
| 管理员账号 CRUD | P1 `admin_account` | 已有登录，缺管理页 |
| 公告插件 `plugin/announcement` | P1 公告管理 | 新表 + `/api/admin/announcements` |
| 操作审计 | P2 `admin_audit_log` | 记录谁在后台改了什么 |
| 用户列表/搜索/分页 | ✅ 部分已有 | 对齐 GVA 表格筛选交互 |
| 富文本/图片上传组件 | P1–P2 | 公告、内容审核可用 |
| 数据字典 | P2 | App 枚举（角色、状态）后台可配 |
| 导出 Excel | P2 | 用户/反馈导出，go-zero 实现 |
| 验证码登录 | 可选 | 内网开发可不做 |

## 明确不借鉴

| GVA 内容 | 原因 |
|----------|------|
| 整套 `server/` Gin 后端 | 已有 go-zero |
| Casbin 细粒度 API 权限 | v1 用 `super_admin` / `admin` 两级即可 |
| spikes/coupons/integral 等电商页 | 非 Moe 业务 |
| 代码生成器 auto-code | 维护 `super.api` + goctl 更合适 |
| Kubernetes / Docker 部署清单 | 已有 Deploy Agent |

## 实现顺序（与 `moe-admin-platform-design.md` 一致）

1. **P1**：公告、通知推送、管理员账号、菜单配置  
2. **P2**：动态/社区审核、操作日志、导出  
3. 每项：`super.api` → RPC → `moe-admin` 页面 → `menu.ts` 标 `ready`
