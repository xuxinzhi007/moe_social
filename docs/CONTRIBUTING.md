# 开发者入口

本文件是**开发者路由页**。项目介绍见 [../README.md](../README.md)，全部文档索引见 [README.md](./README.md)。

## 我该读哪份？

| 我要… | 去看 |
|--------|------|
| 第一次跑起来 | [dev/环境配置说明.md](./dev/环境配置说明.md) · [dev/ports.md](./dev/ports.md) · [dev/快速调试步骤.md](./dev/快速调试步骤.md) |
| 改后端 / 加接口 | [dev/new-api-kratos.md](./dev/new-api-kratos.md) · [../backend/LAYOUT.md](../backend/LAYOUT.md) |
| 改 Flutter 页面 | [../AGENTS.md](../AGENTS.md) · [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md) · [dev/响应式页面模板与检查清单.md](./dev/响应式页面模板与检查清单.md) |
| 了解产品该做什么 | [product/product-positioning.md](./product/product-positioning.md) · [product/prd/](./product/prd/) |
| 发版 | [dev/app-release-cheatsheet.md](./dev/app-release-cheatsheet.md) · [dev/android-release-signing.md](./dev/android-release-signing.md) |
| 运维 / 部署 | [dev/deploy-platform.md](./dev/deploy-platform.md) |
| 提交前过一遍规范 | [../AGENTS.md](../AGENTS.md) · [../code_review.md](../code_review.md) · [dev/API调试指南.md](./dev/API调试指南.md) |

---

## 命令速查

### 客户端

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

API 地址在 `lib/utils/config.dart` 配置（`isProduction` / `productionUrl` / `developmentUrl`），修改后需**完整重启** App。
真机调试时 `127.0.0.1` 指向手机本机，应使用电脑局域网 IP 或线上地址。

### 后端

```bash
cd backend
go mod download
make gen          # 改 api/<domain>/v1/*.proto 后重新生成
make build        # 产出 bin/moe-social（单进程）
make test         # 必须走 make（已写死 CGO_ENABLED=1）
```

> ⚠️ **不要用裸 `go test ./...` 当门禁**：`gorm` 的 sqlite 驱动依赖 cgo，而本机 `go env CGO_ENABLED` 可能持久为 0。
> 此时 DB 用例会静默 `t.Skip`，`go test` 照样报 ok，覆盖率会安静地骗你。
> `make test` 已写死 `CGO_ENABLED=1`；`backend/utils/cgo_canary_test.go` 是配套哨兵。

### 管理台

管理台前端（React/Vite）**已独立成仓，不在本仓**。本仓只保留其 admin 后端契约
（`backend/api/admin/v1/*.proto`、`internal/service/admin/`），改契约后跑：

```bash
cd backend && make gen-moe-admin
```

---

## 仓库结构

```
moe_social/
├── lib/                    # Flutter 客户端
│   ├── app/                # 路由、主 Shell
│   ├── pages/              # 按域划分：feed、chat、ai、arena、commerce、community…
│   ├── services/、providers/、widgets/、models/、utils/、theme/
│   └── main.dart
├── backend/                # Go / Kratos（api/<domain>/v1/*.proto → make gen）
├── docs/                   # 文档中心 → docs/README.md
├── website/official/       # 静态产品官网
├── test/                   # Flutter 测试
└── AGENTS.md               # 仓库贡献与常用命令
```

**不存在的目录**：`moe-admin/`（已独立成仓）、`backend/rpc/`（go-zero 时代产物，已删）、`ops-console/`（已更名并移出）。不要新建或 `cd`。

---

## 发版（维护者）

推送 `v*` Tag（如 `v1.0.3`）触发 GitHub Actions 构建 Release APK 并发布到 GitHub Releases。

```bash
git tag v1.0.3
git push origin v1.0.3
```

- 发版速查（Secrets / 流程 / 别忘清单）：[dev/app-release-cheatsheet.md](./dev/app-release-cheatsheet.md)
- App 内更新：客户端读 `GET /api/public/app-release/latest`（CI 发版后自动回写），设置 → 常规 → 软件版本 可手动检查
- Release 签名：[dev/android-release-signing.md](./dev/android-release-signing.md)
- 后端交叉编译 Linux：`cd backend && make build-linux`（**勿**用 `go env -w GOOS=linux` 改全局）

## 运维部署台（Deploy Agent）

一体化运维界面：构建后端、管理 Docker、触发 GitHub APK 流水线。

```bash
cd backend
cp deploy/config.example.yaml deploy/config.yaml   # 修改 token
make deploy-agent
# 浏览器打开 http://127.0.0.1:19010/
```

详见 [dev/deploy-platform.md](./dev/deploy-platform.md)。

---

## 文档维护约定

1. **一个主题一份 SSOT**，其余只写增量。
2. **方案落地后**：更新 SSOT 变更记录；过时文档**直接删除**，不保留 `archive/` stub。
3. **文件名带日期**表示一次性快照，用完即删，不要长期留在索引里。
4. 新增文档放 `docs/<category>/`，避免在仓库根目录堆积。
