# cmd/ 入口

| 命令 | 说明 |
|------|------|
| `make moe-social` | 生产主程序（Kratos HTTP :8888） |
| `make moe-social-dev` | 同上 + deploy-agent :19010 |
| `make db-migrate` | 数据库迁移 |
| `make deploy-agent` | 部署调试代理 |
| `make temp-mail-password EMAIL=foo@web-library.net` | 计算临时邮箱对应密码 |

## Temp Mail Password

临时邮箱密码由后端按固定规则计算，不是注册页里填写的 App 密码。

示例：

```bash
cd backend
make temp-mail-password EMAIL=moea61i1yz88jpf@web-library.net
```

也可以直接运行：

```bash
cd backend
go run ./cmd/temp-mail-password --email moea61i1yz88jpf@web-library.net
```
