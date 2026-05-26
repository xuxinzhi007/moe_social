package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"strings"

	"backend/rpc/internal/bootstrap"
	"backend/rpc/internal/config"
	"backend/rpc/internal/debug"
	"backend/rpc/internal/server"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/conf"
	"github.com/zeromicro/go-zero/core/service"
	"github.com/zeromicro/go-zero/zrpc"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

var configFile = flag.String("f", "etc/super.yaml", "the config file")

// 新增/变更模型后执行 go run super.go -migrate（迁移完成后照常启动 RPC）
var migrate = flag.Bool("migrate", false, "run schema migrate before starting RPC")
var migrateModels = flag.String("migrate-models", "", "with -migrate: comma-separated table keys (empty=all)")
var migrateForce = flag.Bool("migrate-force", false, "with -migrate: ignore schema hash cache")

// 开发调试：暴露 /debug/*（默认 devports :19011）。日常 go run super.go 不要加；用 make rpc-debug。
var enableDebug = flag.Bool("debug", false, "expose local debug HTTP API on loopback (dev only; use make rpc-debug)")

func main() {
	flag.Parse()

	var c config.Config
	conf.MustLoad(*configFile, &c)
	ctx := svc.NewServiceContext(c, utils.MigrateOptions{
		Enabled: *migrate,
		Models:  utils.ParseMigrateModelKeys(*migrateModels),
		Force:   *migrateForce,
	})

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

	bootstrap.StartMoeBotScheduler(context.Background(), ctx)

	fmt.Printf("Starting rpc server at %s...\n", c.ListenOn)
	s.Start()
}

func debugEnabled() bool {
	if *enableDebug {
		return true
	}
	return strings.EqualFold(strings.TrimSpace(os.Getenv("MOE_RPC_MONITOR")), "on")
}
