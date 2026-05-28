# backend/scripts

## 日常验收（推荐）

| 命令 | 脚本 | 何时跑 |
|------|------|--------|
| `make verify` | `verify/kratos-pure-100.sh` | 改 Kratos / 启动 / 配置 |
| `make verify-kratos-regression` | `verify/kratos-regression.sh` | PK PR（pure-100 + fs9b） |
| `make verify-sprint-fs9` | `verify/fs9.sh` | 契约文件名（较重，含 fs8b） |
| `make verify-kratos-regression-full` | `verify/kratos-regression-full.sh` | 发版、大批合并 |

## 目录

```text
scripts/
  lib/backend-root.sh     # 定位 backend 根目录
  verify/                 # 活跃门禁
    kratos-*.sh           # 纯 Kratos
    fs9.sh / fs9b.sh      # 契约
    sprint/               # F 业务迁移（biz+gw）
    domain/               # 域 / Hybrid 组合
  _archive/kratos-pk/     # 历史 PK-0～12 里程碑（只存档，Makefile 不再调用）
  gen-*.sh                # 代码生成
```

## 运行时 vs 目录

生产 **`make moe-social`** 已是 **单进程 Kratos**（HTTP :8888 + gRPC :8080）。  
仓库仍保留 **`api/`**（HTTP handler/logic）与 **`rpc/`**（gRPC logic）是 **goctl 生成链与历史分层**，不是两个独立部署单元。详见 [LAYOUT.md](../LAYOUT.md)。
