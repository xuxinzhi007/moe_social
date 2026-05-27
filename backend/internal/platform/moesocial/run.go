package moesocial

import (
	"context"
	"fmt"
	"log"
	"net"
	"strings"
	"time"

	apirun "backend/api/runserver"
	rpcrun "backend/rpc/runserver"
	"backend/utils"

	"github.com/go-kratos/kratos/v2"
	"github.com/zeromicro/go-zero/core/conf"
	"github.com/zeromicro/go-zero/zrpc"
)

// Options 单进程启动参数。
type Options struct {
	APIConfigFile string
	RPCConfigFile string
	Migrate       utils.MigrateOptions
}

// Run 在单个 OS 进程内启动 RPC + HTTP（Kratos 编排 API；RPC 先起），替代分离的 make rpc + make api。
func Run(opts Options) error {
	rpcSrv, _, err := rpcrun.Start(rpcrun.Options{
		ConfigFile: opts.RPCConfigFile,
		Migrate:    opts.Migrate,
	})
	if err != nil {
		return fmt.Errorf("rpc start: %w", err)
	}

	rpcDone := make(chan struct{}, 1)
	go func() { rpcSrv.Start(); close(rpcDone) }()

	if err := waitRPCListen(opts.RPCConfigFile, 15*time.Second); err != nil {
		rpcSrv.Stop()
		return err
	}

	apiSrv, err := apirun.Start(apirun.Options{ConfigFile: opts.APIConfigFile})
	if err != nil {
		rpcSrv.Stop()
		return fmt.Errorf("api start: %w", err)
	}

	app := kratos.New(
		kratos.Name("moe-social"),
		kratos.Server(wrapREST(apiSrv)),
		kratos.AfterStop(func(context.Context) error {
			rpcSrv.Stop()
			return nil
		}),
	)
	rpcAddr, _ := rpcListenAddr(opts.RPCConfigFile)
	apiAddr := apiListenAddr(opts.APIConfigFile)
	log.Printf("moe-social: 单进程已就绪（非单端口）— gRPC %s + HTTP %s", rpcAddr, apiAddr)
	log.Print("  · 管理台/App 请访问 HTTP 端口；API 内 Moe 走 in_process，无需再开第二个终端")
	_ = rpcDone
	return app.Run()
}

func waitRPCListen(configFile string, timeout time.Duration) error {
	addr, err := rpcListenAddr(configFile)
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

func rpcListenAddr(configFile string) (string, error) {
	var c zrpc.RpcServerConf
	conf.MustLoad(configFile, &c)
	return normalizeListenAddr(c.ListenOn, "8080"), nil
}

func apiListenAddr(configFile string) string {
	var c struct {
		Host string `json:",optional"`
		Port int    `json:",optional"`
	}
	conf.MustLoad(configFile, &c)
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
