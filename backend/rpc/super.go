package main

import (
	"backend/rpc/internal/config"
	"backend/rpc/internal/debug"
	"backend/rpc/internal/server"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/zeromicro/go-zero/core/conf"
	"github.com/zeromicro/go-zero/core/service"
	"github.com/zeromicro/go-zero/zrpc"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

var configFile = flag.String("f", "etc/super.yaml", "the config file")

// 新增/变更模型后执行  go run super.go -migrate（仅建表，不写入 VIP/礼物/成就等运营数据）
var migrate = flag.Bool("migrate", false, "run GORM AutoMigrate once at startup (schema only); omit for normal start")

// 开发调试：暴露 /debug/*（默认 devports :19011）。日常 go run super.go 不要加；用 make rpc-debug。
var enableDebug = flag.Bool("debug", false, "expose local debug HTTP API on loopback (dev only; use make rpc-debug)")

func main() {
	flag.Parse()

	var c config.Config
	conf.MustLoad(*configFile, &c)
	ctx := svc.NewServiceContext(c, *migrate)

	s := zrpc.MustNewServer(c.RpcServerConf, func(grpcServer *grpc.Server) {
		super.RegisterSuperServer(grpcServer, server.NewSuperServer(ctx))

		if c.Mode == service.DevMode || c.Mode == service.TestMode {
			reflection.Register(grpcServer)
		}
	})
	defer s.Stop()

	if debugEnabled() {
		monitor := debug.StartMonitor("")
		if monitor != nil {
			defer monitor.Stop()
		}
	}

	fmt.Printf("Starting rpc server at %s...\n", c.ListenOn)
	s.Start()
}

func debugEnabled() bool {
	if *enableDebug {
		return true
	}
	return strings.EqualFold(strings.TrimSpace(os.Getenv("MOE_RPC_MONITOR")), "on")
}
