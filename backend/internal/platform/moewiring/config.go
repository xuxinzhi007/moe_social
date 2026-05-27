package moewiring

import (
	"sync"

	"github.com/spf13/viper"
)

var (
	configOnce sync.Once
	configV    *viper.Viper
)

func moeViper() *viper.Viper {
	configOnce.Do(func() {
		v := viper.New()
		v.SetConfigName("config")
		v.SetConfigType("yaml")
		v.AddConfigPath("./config")
		v.AddConfigPath("../config")
		v.AddConfigPath("../../config")
		_ = v.ReadInConfig()
		configV = v
	})
	return configV
}

func boolOr(v *viper.Viper, keys []string, def bool) bool {
	if v == nil {
		return def
	}
	for _, key := range keys {
		if v.IsSet(key) {
			return v.GetBool(key)
		}
	}
	return def
}

// APIInProcessEnabled config.yaml: moe.api_in_process
func APIInProcessEnabled() bool {
	return boolOr(moeViper(), []string{"moe.api_in_process"}, false)
}

// RegisterMoeGRPCEnabled config.yaml: moe.register_moe_grpc（兼容旧键 register_v1_grpc）
func RegisterMoeGRPCEnabled() bool {
	return boolOr(moeViper(), []string{"moe.register_moe_grpc", "moe.register_v1_grpc"}, true)
}

// UseMoeGRPCEnabled config.yaml: moe.use_moe_grpc（兼容旧键 use_v1_grpc）
func UseMoeGRPCEnabled() bool {
	return boolOr(moeViper(), []string{"moe.use_moe_grpc", "moe.use_v1_grpc"}, true)
}

// SingleProcessEnabled 使用 cmd/moe-social 单进程时建议为 true（强制 api_in_process 语义）。
func SingleProcessEnabled() bool {
	return boolOr(moeViper(), []string{"moe.single_process"}, false)
}
