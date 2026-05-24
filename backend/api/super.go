package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"backend/api/internal/config"
	"backend/api/internal/handler"
	"backend/api/internal/svc"
	"backend/utils"

	"github.com/spf13/viper"
	"github.com/zeromicro/go-zero/core/conf"
	"github.com/zeromicro/go-zero/rest"
)

var configFile = flag.String("f", "etc/super.yaml", "the config file")

// applyUnifiedConfigOverrides 尝试从 backend/config/config.yaml 读取统一配置并覆盖部分字段。
// 例如 Ollama、REST 超时、app_client.public_api_base_url、image.*（不必写进 etc/super.yaml）。
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
	if dir := v.GetString("local_models.storage_dir"); dir != "" {
		c.LocalModels.StorageDir = dir
	}
	if v.IsSet("local_models.catalog") {
		var entries []config.LocalModelCatalogEntry
		if err := v.UnmarshalKey("local_models.catalog", &entries); err == nil && len(entries) > 0 {
			c.LocalModels.Catalog = entries
		}
	}
	if timeoutMs := v.GetInt64("api.timeout_ms"); timeoutMs > 0 {
		// go-zero RestConf 的 Timeout 通常为毫秒单位的 int64
		c.Timeout = timeoutMs
	}
	if u := v.GetString("app_client.public_api_base_url"); u != "" {
		c.ClientPublicApiBaseUrl = u
	}
	// 图片云空间：与 api/etc/super.yaml 的 Image 合并，便于本地/服务器只改 backend/config/config.yaml。
	// 同时兼容两种命名风格：
	// 1) image.local_dir / image.public_base_url / image.max_bytes
	// 2) Image.LocalDir / Image.PublicBaseUrl / Image.MaxBytes
	if d := firstNonEmptyString(v, "image.local_dir", "image.localdir"); d != "" {
		c.Image.LocalDir = d
	}
	if u := firstNonEmptyString(v, "image.public_base_url", "image.publicbaseurl"); u != "" {
		c.Image.PublicBaseUrl = u
	}
	if n := firstPositiveInt64(v, "image.max_bytes", "image.maxbytes"); n > 0 {
		c.Image.MaxBytes = n
	}
	if secret := strings.TrimSpace(os.Getenv("MOE_AUTH_ACCESS_SECRET")); secret != "" {
		c.Auth.AccessSecret = secret
	} else if secret := firstNonEmptyString(v, "auth.access_secret"); secret != "" {
		c.Auth.AccessSecret = secret
	}
	if exp := v.GetInt64("auth.access_expire_seconds"); exp > 0 {
		c.Auth.AccessExpire = exp
	}
	if secret := firstNonEmptyString(v, "admin.jwt_secret"); secret != "" {
		hours := v.GetInt64("admin.token_expire_hours")
		if hours <= 0 {
			hours = 24
		}
		_ = utils.ConfigureAdminJWT(secret, hours)
	}
	applySuperRpcOverrides(c, v)
}

// applySuperRpcOverrides 解析 API→RPC 地址（优先级：环境变量 > config.yaml > etc/super.yaml）。
// Docker Compose 注入 MOE_SUPER_RPC_ENDPOINT=rpc:8080；本机 go run 不设则沿用 127.0.0.1:8080。
func applySuperRpcOverrides(c *config.Config, v *viper.Viper) {
	if ep := strings.TrimSpace(os.Getenv("MOE_SUPER_RPC_ENDPOINT")); ep != "" {
		c.SuperRpc.Endpoints = splitRPCEndpoints(ep)
		return
	}
	if v != nil {
		if eps := v.GetStringSlice("api.super_rpc_endpoints"); len(eps) > 0 {
			c.SuperRpc.Endpoints = eps
		}
	}
}

func splitRPCEndpoints(raw string) []string {
	var out []string
	for _, p := range strings.Split(raw, ",") {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

func firstNonEmptyString(v *viper.Viper, keys ...string) string {
	for _, key := range keys {
		if value := strings.TrimSpace(v.GetString(key)); value != "" {
			return value
		}
	}
	return ""
}

func firstPositiveInt64(v *viper.Viper, keys ...string) int64 {
	for _, key := range keys {
		if value := v.GetInt64(key); value > 0 {
			return value
		}
	}
	return 0
}

func main() {
	flag.Parse()

	var c config.Config
	conf.MustLoad(*configFile, &c)
	applyUnifiedConfigOverrides(&c)
	if err := utils.ConfigureJWT(c.Auth.AccessSecret, c.Auth.AccessExpire); err != nil {
		log.Fatalf("JWT 配置无效: %v（请在 backend/config/config.yaml 设置 auth.access_secret）", err)
	}

	// 使用go-zero内置的CORS支持，允许所有来源（开发环境）
	server := rest.MustNewServer(c.RestConf, rest.WithCustomCors(
		func(header http.Header) {
			header.Set("Access-Control-Allow-Origin", "*")
			header.Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, PATCH")
			header.Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Admin-Token, X-Requested-With, Accept, Range")
			header.Set("Access-Control-Expose-Headers", "Content-Length, Content-Range, Accept-Ranges, X-Model-Sha256")
			header.Set("Access-Control-Max-Age", "3600")
		},
		nil,
		"*",
	))
	defer server.Stop()

	ctx := svc.NewServiceContext(c)
	handler.RegisterHandlers(server, ctx)

	fmt.Printf("Effective image config: local_dir=%s public_base_url=%s max_bytes=%d\n",
		c.Image.LocalDir, c.Image.PublicBaseUrl, c.Image.MaxBytes)

	fmt.Printf("SuperRpc endpoints: %v\n", c.SuperRpc.Endpoints)
	fmt.Printf("Starting server at %s:%d...\n", c.Host, c.Port)
	server.Start()
}
