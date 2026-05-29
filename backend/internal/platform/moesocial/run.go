package moesocial

import (
	"fmt"
	"net"
	"strings"
	"time"

	"backend/internal/platform/moewiring"
	"backend/internal/platform/yamlconf"
	"backend/utils"
)

// Options 单进程启动参数（PK-13：UnifiedConfigFile 为 SSOT，API/RPC 片段自动解析）。
type Options struct {
	UnifiedConfigFile string
	APIConfigFile     string
	RPCConfigFile     string
	Migrate           utils.MigrateOptions
	EnableRPCMonitor  bool
}

// Run 在单个 OS 进程内启动 RPC + HTTP（生产：Kratos gRPC + 纯 Kratos HTTP）。
func Run(opts Options) error {
	opts.NormalizeOptions()
	if !moewiring.KratosSuperGRPCNative() {
		return fmt.Errorf("zrpc RPC path removed; set moe.kratos_super_grpc_native=true in config")
	}
	return runWithKratosGRPC(opts)
}

func waitRPCListen(unified, rpcFragment string, timeout time.Duration) error {
	addr, err := rpcListenAddr(unified, rpcFragment)
	if err != nil {
		return err
	}
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("tcp", addr, 200*time.Millisecond)
		if err == nil {
			_ = conn.Close()
			return nil
		}
		time.Sleep(100 * time.Millisecond)
	}
	return fmt.Errorf("rpc not ready on %s within %s", addr, timeout)
}

func rpcListenAddr(unified, rpcFragment string) (string, error) {
	if addr := grpcListenFromUnified(unified); addr != "" {
		return normalizeListenAddr(addr, "8080"), nil
	}
	var c struct {
		ListenOn string `yaml:"ListenOn"`
	}
	yamlconf.MustLoad(rpcFragment, &c)
	return normalizeListenAddr(c.ListenOn, "8080"), nil
}

func externalHTTPPort(unified, apiFragment string) int {
	if p := httpPortFromUnified(unified); p > 0 {
		return p
	}
	var c struct {
		Port int `yaml:"Port"`
	}
	yamlconf.MustLoad(apiFragment, &c)
	if c.Port <= 0 {
		return 8888
	}
	return c.Port
}

func apiListenAddr(configFile string) string {
	var c struct {
		Host string `yaml:"Host"`
		Port int    `yaml:"Port"`
	}
	yamlconf.MustLoad(configFile, &c)
	if c.Port <= 0 {
		c.Port = 8888
	}
	host := strings.TrimSpace(c.Host)
	if host == "" {
		host = "0.0.0.0"
	}
	return normalizeListenAddr(fmt.Sprintf("%s:%d", host, c.Port), "8888")
}

func normalizeListenAddr(host, defaultPort string) string {
	host = strings.TrimSpace(host)
	if host == "" {
		host = "0.0.0.0:" + defaultPort
	}
	if strings.HasPrefix(host, ":") {
		host = "0.0.0.0" + host
	}
	if !strings.Contains(host, ":") {
		host = host + ":" + defaultPort
	}
	return strings.Replace(host, "0.0.0.0", "127.0.0.1", 1)
}
