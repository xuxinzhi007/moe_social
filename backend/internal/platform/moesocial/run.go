package moesocial

import (
	"context"
	"fmt"
	"log"
	"net"
	"strings"
	"time"

	apirun "backend/api/runserver"
	"backend/devports"
	"backend/internal/platform/moewiring"
	rpcrun "backend/rpc/runserver"
	"backend/utils"

	"github.com/go-kratos/kratos/v2"
	"github.com/zeromicro/go-zero/core/conf"
	"github.com/zeromicro/go-zero/zrpc"
)

// Options 单进程启动参数。
type Options struct {
	APIConfigFile    string
	RPCConfigFile    string
	Migrate          utils.MigrateOptions
	EnableRPCMonitor bool // 本地 :19011 debug API（moe-admin RPC 监控经 Agent 转发）
}

// Run 在单个 OS 进程内启动 RPC + HTTP（Kratos 编排 API；RPC 先起），替代分离的 make rpc + make api。
func Run(opts Options) error {
	rpcSrv, _, rpcMonitor, err := rpcrun.Start(rpcrun.Options{
		ConfigFile:     opts.RPCConfigFile,
		Migrate:        opts.Migrate,
		EnableMonitor:  opts.EnableRPCMonitor,
	})
	if err != nil {
		return fmt.Errorf("rpc start: %w", err)
	}

	rpcManaged := moewiring.KratosGRPCManaged()
	// 无论是否 kratos 托管，都先启动 zrpc 再 wait（PK-7 前 wait 时 RPC 必须已监听）。
	go func() { rpcSrv.Start() }()

	if err := waitRPCListen(opts.RPCConfigFile, 15*time.Second); err != nil {
		rpcSrv.Stop()
		return err
	}

	if rpcMonitor != nil {
		log.Printf("moe-social: RPC debug API %s/debug/live (经 deploy-agent /debug/* 访问)", devports.RpcDebugUpstream())
	}

	apiOpts := apirun.Options{ConfigFile: opts.APIConfigFile}
	var httpSrv interface {
		Start(context.Context) error
		Stop(context.Context) error
	}
	var apiAddr string

	if moewiring.KratosPureHTTPWithoutLegacy() {
		apiOpts.WireOnly = true
		apiRes, err := apirun.StartWithResult(apiOpts)
		if err != nil {
			if rpcMonitor != nil {
				rpcMonitor.Stop()
			}
			rpcSrv.Stop()
			return fmt.Errorf("api wire: %w", err)
		}
		port := externalHTTPPort(opts.APIConfigFile)
		pure, err := newKratosPureHTTPServer(apiRes, "0.0.0.0", port)
		if err != nil {
			if rpcMonitor != nil {
				rpcMonitor.Stop()
			}
			rpcSrv.Stop()
			return fmt.Errorf("kratos pure http: %w", err)
		}
		httpSrv = pure
		apiAddr = fmt.Sprintf("0.0.0.0:%d", port)
		log.Printf("moe-social: pure Kratos HTTP %s (no go-zero rest)", apiAddr)
	} else if moewiring.KratosHTTPFrontEnabled() {
		internalPort := moewiring.KratosInternalHTTPPort()
		apiOpts.InternalHTTPPort = internalPort
		apiOpts.InternalHTTPHost = "127.0.0.1"
		apiRes, err := apirun.StartWithResult(apiOpts)
		if err != nil {
			if rpcMonitor != nil {
				rpcMonitor.Stop()
			}
			rpcSrv.Stop()
			return fmt.Errorf("api start: %w", err)
		}
		front, err := newKratosFrontServer(apiRes, "0.0.0.0", externalHTTPPort(opts.APIConfigFile))
		if err != nil {
			if apiRes.Server != nil {
				apiRes.Server.Stop()
			}
			if rpcMonitor != nil {
				rpcMonitor.Stop()
			}
			rpcSrv.Stop()
			return fmt.Errorf("kratos front: %w", err)
		}
		httpSrv = front
		apiAddr = fmt.Sprintf("0.0.0.0:%d", externalHTTPPort(opts.APIConfigFile))
		log.Printf("moe-social: PK-4 enabled — Kratos HTTP %s, go-zero 127.0.0.1:%d (fallback)", apiAddr, internalPort)
	} else if moewiring.KratosHybridHTTPFallback() {
		apiSrv, err := apirun.Start(apiOpts)
		if err != nil {
			if rpcMonitor != nil {
				rpcMonitor.Stop()
			}
			rpcSrv.Stop()
			return fmt.Errorf("api start: %w", err)
		}
		httpSrv = wrapREST(apiSrv)
		apiAddr = apiListenAddr(opts.APIConfigFile)
		log.Printf("moe-social: PK-8 hybrid fallback — go-zero HTTP %s", apiAddr)
	} else {
		if rpcMonitor != nil {
			rpcMonitor.Stop()
		}
		rpcSrv.Stop()
		return fmt.Errorf("PK-8: go-zero HTTP retired; set moe.kratos_pure_enabled=true or moe.kratos_hybrid_http_fallback=true")
	}

	kratosOpts := []kratos.Option{
		kratos.Name("moe-social"),
		kratos.AfterStop(func(context.Context) error {
			if rpcMonitor != nil {
				rpcMonitor.Stop()
			}
			if !rpcManaged {
				rpcSrv.Stop()
			}
			return nil
		}),
	}
	if rpcManaged {
		kratosOpts = append(kratosOpts, kratos.Server(httpSrv, wrapZRPC(rpcSrv)))
	} else {
		kratosOpts = append(kratosOpts, kratos.Server(httpSrv))
	}
	app := kratos.New(kratosOpts...)
	rpcAddr, _ := rpcListenAddr(opts.RPCConfigFile)
	log.Printf("moe-social: 单进程已就绪 — gRPC %s + HTTP %s", rpcAddr, apiAddr)
	log.Printf("moe-social: 对外请使用 HTTP %s（Flutter / moe-admin / 第三方 REST 不变）", apiAddr)
	if moewiring.KratosPureEnabled() {
		log.Print("  · PK-9: 纯 Kratos 生产（transport/http + transport/grpc）")
	} else if moewiring.KratosHTTPFrontEnabled() {
		log.Print("  · PK-4: Kratos HTTP :8888（未匹配路由回退 go-zero 内网）")
	} else if moewiring.KratosHybridHTTPFallback() {
		log.Print("  · PK-8 hybrid fallback: go-zero HTTP（紧急回滚）")
	}
	if rpcManaged {
		log.Print("  · gRPC :8080 由 kratos.App 管理")
	}
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

func externalHTTPPort(configFile string) int {
	var c struct {
		Port int `json:",optional"`
	}
	conf.MustLoad(configFile, &c)
	if c.Port <= 0 {
		return 8888
	}
	return c.Port
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
