package runserver

import (
	"strings"

	"backend/rpc/internal/config"

	"github.com/spf13/viper"
)

// ApplyUnifiedConfigOverrides 从 backend/config/config.yaml（SSOT）合并 RPC 监听与超时等。
func ApplyUnifiedConfigOverrides(c *config.Config) {
	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")
	if err := v.ReadInConfig(); err != nil {
		return
	}
	if listen := strings.TrimSpace(v.GetString("runtime.grpc_listen")); listen != "" {
		c.ListenOn = listen
	} else if port := strings.TrimSpace(v.GetString("moe.production.internal_grpc_port")); port != "" {
		if strings.Contains(port, ":") {
			c.ListenOn = port
		} else {
			c.ListenOn = "0.0.0.0:" + port
		}
	}
	if ms := v.GetInt64("runtime.rpc_timeout_ms"); ms > 0 {
		c.Timeout = ms
	} else if ms := v.GetInt64("api.timeout_ms"); ms > 0 {
		c.Timeout = ms
	}
	if v.IsSet("runtime.hand_draw_require_moderation") {
		c.HandDrawRequireModeration = v.GetBool("runtime.hand_draw_require_moderation")
	}
}
