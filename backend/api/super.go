package main

import (
	"flag"
	"fmt"
	"net/http"

	"backend/api/internal/config"
	"backend/api/internal/handler"
	llmhandler "backend/api/internal/handler/llm"
	"backend/api/internal/svc"

	"github.com/spf13/viper"
	"github.com/zeromicro/go-zero/core/conf"
	"github.com/zeromicro/go-zero/rest"
)

var configFile = flag.String("f", "etc/super.yaml", "the config file")

// applyUnifiedConfigOverrides 尝试从 backend/config/config.yaml 读取统一配置并覆盖部分字段。
// 这样做的好处是：你可以在一个地方管理 “Ollama 地址/超时” 等参数，而不必每次都改 etc/super*.yaml。
// 注意：如果找不到/读取失败，会静默跳过，保持原有 go-zero 配置行为不变。
func applyUnifiedConfigOverrides(c *config.Config) {
	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")

	// 常见运行方式：
	// - cd backend/api && go run super.go -f etc/super.yaml   => ../config
	// - cd backend && go run api/super.go -f api/etc/super.yaml => ./config
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")

	if err := v.ReadInConfig(); err != nil {
		return
	}

	if base := v.GetString("ollama.base_url"); base != "" {
		c.Ollama.BaseUrl = base
	}
	if ts := v.GetInt("ollama.timeout_seconds"); ts > 0 {
		c.Ollama.TimeoutSeconds = ts
	}
	if timeoutMs := v.GetInt64("api.timeout_ms"); timeoutMs > 0 {
		// go-zero RestConf 的 Timeout 通常为毫秒单位的 int64
		c.Timeout = timeoutMs
	}
}

func main() {
	flag.Parse()

	var c config.Config
	conf.MustLoad(*configFile, &c)
	applyUnifiedConfigOverrides(&c)

	// 使用go-zero内置的CORS支持，允许所有来源（开发环境）
	server := rest.MustNewServer(c.RestConf, rest.WithCustomCors(
		func(header http.Header) {
			header.Set("Access-Control-Allow-Origin", "*")
			header.Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, PATCH")
			header.Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With, Accept")
			header.Set("Access-Control-Max-Age", "3600")
		},
		nil,
		"*",
	))
	defer server.Stop()

	ctx := svc.NewServiceContext(c)
	handler.RegisterHandlers(server, ctx)

	// 手动追加"流式聊天"接口（SSE 和 WebSocket）。不写入 super.api，避免 goctl 生成覆盖/不适配流式响应。
	server.AddRoutes(
		[]rest.Route{
			{
				Method:  http.MethodPost,
				Path:    "/api/llm/chat/stream",
				Handler: llmhandler.ChatStreamHandler(ctx),
			},
			{
				Method:  http.MethodGet,
				Path:    "/api/llm/chat/ws",
				Handler: llmhandler.ChatWebSocketHandler(ctx),
			},
		},
	)

	fmt.Printf("Starting server at %s:%d...\n", c.Host, c.Port)
	server.Start()
}
