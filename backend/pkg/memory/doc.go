// Package memory 提供与 HTTP/RPC/具体 ORM 无关的通用记忆域逻辑。
//
// 分层约定：
//   - L1 本包：类型、过滤、检索排序、画像聚合、Store 接口
//   - L2 适配：api/rpc handler 将请求转为 Record，调用本包后写回响应
//   - L3 存储：GORM model.UserMemory、RPC Super 等实现 Store 接口（逐步迁移）
//
// 其他服务（独立 API、Worker、未来微服务）应只依赖本包 + 自有 Store 实现，避免复制检索/过滤规则。
package memory
