// Package moeconf 从 config.yaml 加载 moe.conf.v1.Bootstrap（Phase 4 SSOT）。
package moeconf

import (
	"strings"
	"sync"

	moeconfv1 "backend/internal/conf/moe/v1"
	"backend/utils"

	"github.com/spf13/viper"
)

var (
	bootstrapOnce sync.Once
	bootstrap     *moeconfv1.Bootstrap
	bootstrapErr  error
)

// LoadBootstrap 读取并缓存 Bootstrap（先 InitConfig，再映射 moe 段）。
func LoadBootstrap() (*moeconfv1.Bootstrap, error) {
	bootstrapOnce.Do(func() {
		if err := utils.InitConfig(); err != nil {
			bootstrapErr = err
			return
		}
		v := viper.New()
		v.SetConfigName("config")
		v.SetConfigType("yaml")
		v.AddConfigPath("./config")
		v.AddConfigPath("../config")
		v.AddConfigPath("../../config")
		if err := v.ReadInConfig(); err != nil {
			bootstrapErr = err
			return
		}
		bootstrap = mapViperToBootstrap(v)
	})
	return bootstrap, bootstrapErr
}

// ResetBootstrapForTest 仅测试用，清空缓存。
func ResetBootstrapForTest() {
	bootstrapOnce = sync.Once{}
	bootstrap = nil
	bootstrapErr = nil
}

func mapViperToBootstrap(v *viper.Viper) *moeconfv1.Bootstrap {
	if v == nil {
		return &moeconfv1.Bootstrap{
			Server:     &moeconfv1.PilotServer{},
			Moe:        &moeconfv1.PilotMoe{},
			Production: &moeconfv1.ProductionPorts{},
			Vip:        &moeconfv1.PilotVip{},
		}
	}
	return &moeconfv1.Bootstrap{
		Server: &moeconfv1.PilotServer{
			GrpcAddr:         v.GetString("moe.pilot.grpc_addr"),
			HttpAddr:         v.GetString("moe.pilot.http_addr"),
			SuperRpcEndpoint: v.GetString("moe.pilot.super_rpc_endpoint"),
		},
		Production: &moeconfv1.ProductionPorts{
			UnifiedEntry:      v.GetString("moe.production.unified_entry"),
			ExternalHttpPort:  v.GetString("moe.production.external_http_port"),
			InternalGrpcPort:  v.GetString("moe.production.internal_grpc_port"),
			PilotHttpPort:     v.GetString("moe.production.pilot_http_port"),
			PilotGrpcPort:     v.GetString("moe.production.pilot_grpc_port"),
		},
		Vip: &moeconfv1.PilotVip{
			AdminReadEnabled: v.GetBool("moe.pilot.vip_admin_read_enabled"),
		},
		Moe: &moeconfv1.PilotMoe{
			ApiInProcess:            v.GetBool("moe.api_in_process"),
			RegisterMoeGrpc:         getBool(v, "moe.register_moe_grpc", "moe.register_v1_grpc"),
			UseMoeGrpc:              getBool(v, "moe.use_moe_grpc", "moe.use_v1_grpc"),
			SingleProcess:           v.GetBool("moe.single_process"),
			KratosAdminHttpEnabled:  v.GetBool("moe.kratos_admin_http_enabled"),
			KratosAdminBaseUrl:      strings.TrimSpace(v.GetString("moe.kratos_admin_base_url")),
			KratosVipHttpEnabled:    v.GetBool("moe.kratos_vip_http_enabled"),
		},
	}
}

func getBool(v *viper.Viper, keys ...string) bool {
	for _, k := range keys {
		if v.IsSet(k) {
			return v.GetBool(k)
		}
	}
	return false
}
