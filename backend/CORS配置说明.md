# CORS跨域配置说明

## ✅ 已完成的配置

### 1. 创建CORS中间件
- ✅ `backend/api/internal/middleware/corsmiddleware.go` - CORS中间件实现

### 2. 注册中间件
- ✅ `backend/api/super.go` - 在服务器启动时注册CORS中间件

## 🔧 CORS中间件功能

### 允许的配置
- **允许的来源**: 所有来源（开发环境），生产环境建议限制特定域名
- **允许的方法**: GET, POST, PUT, DELETE, OPTIONS, PATCH
- **允许的头部**: Content-Type, Authorization, X-Requested-With
- **允许凭证**: true（支持携带Cookie等凭证）
- **预检缓存**: 3600秒

### 工作原理
1. **预检请求处理**: 自动处理OPTIONS预检请求
2. **动态Origin**: 根据请求的Origin头动态设置允许的来源
3. **开发环境**: 如果没有Origin头，允许所有来源（*）

## 🚀 使用方法

### 重启API服务
修改后需要重启API服务才能生效：

```bash
cd backend/api
go run super.go
```

### 验证CORS
1. 启动前端应用
2. 尝试登录
3. 检查浏览器控制台，应该不再有CORS错误

## ⚠️ 生产环境建议

### 限制允许的来源
在生产环境中，建议修改CORS中间件，只允许特定的域名：

```go
// 允许的域名列表
allowedOrigins := []string{
    "https://yourdomain.com",
    "https://www.yourdomain.com",
}

origin := r.Header.Get("Origin")
if contains(allowedOrigins, origin) {
    w.Header().Set("Access-Control-Allow-Origin", origin)
}
```

### 安全考虑
- 不要在生产环境使用 `Access-Control-Allow-Origin: *`
- 限制允许的HTTP方法
- 限制允许的请求头
- 考虑添加速率限制

## 📝 测试

### 测试步骤
1. 确保API服务正在运行（端口8888）
2. 启动前端应用
3. 尝试登录
4. 检查浏览器控制台，确认没有CORS错误

### 预期结果
- ✅ 登录请求成功
- ✅ 没有CORS错误
- ✅ 可以正常获取响应数据

## 🔍 故障排查

### 如果仍然有CORS错误
1. **确认API服务已重启**: 修改后必须重启服务
2. **检查中间件是否注册**: 确认`server.Use(corsMiddleware.Handle)`已执行
3. **检查浏览器缓存**: 清除浏览器缓存后重试
4. **检查网络请求**: 在浏览器开发者工具的Network标签中查看请求头

### 常见问题
- **预检请求失败**: 确保OPTIONS方法被正确处理
- **凭证问题**: 如果使用Cookie，确保`Access-Control-Allow-Credentials`为true
- **头部问题**: 确保所有需要的请求头都在`Access-Control-Allow-Headers`中

