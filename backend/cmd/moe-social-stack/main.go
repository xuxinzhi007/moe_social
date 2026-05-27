// 开发用：单进程 moe-social + 可选 deploy-agent（:19010）。
//
//	make moe-social 默认走本入口；生产二进制仍用 cmd/moe-social。
//
//	go run ./cmd/moe-social-stack -agent=false  # 仅 :8888+:8080
package main

import (
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"

	"backend/devlauncher"
	"backend/internal/platform/moesocial"
	"backend/utils"
)

var (
	apiConfig = flag.String("f-api", "api/etc/super.yaml", "API config (go-zero rest)")
	rpcConfig = flag.String("f-rpc", "rpc/etc/super.yaml", "RPC config (go-zero zrpc)")
	migrate   = flag.Bool("migrate", false, "run schema migrate before starting")
	withAgent   = flag.Bool("agent", true, "start deploy-agent on :19010 (devtools / deploy proxy)")
	withMonitor = flag.Bool("monitor", true, "RPC debug API on :19011 for moe-admin RPC 监控")
)

func main() {
	flag.Parse()

	root, err := devlauncher.FindBackendRoot()
	if err != nil {
		log.Fatal(err)
	}

	var agentProc *devlauncher.ManagedProcess
	stopAgent := func() {
		if agentProc != nil {
			devlauncher.StopManaged(agentProc)
			agentProc = nil
		}
	}
	if *withAgent {
		agentProc, err = devlauncher.StartDeployAgent(root)
		if err != nil {
			log.Printf("deploy-agent: %v (continuing without agent)", err)
		} else {
			defer stopAgent()
			sigCh := make(chan os.Signal, 1)
			signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)
			go func() {
				<-sigCh
				stopAgent()
			}()
		}
	}

	if err := moesocial.Run(moesocial.Options{
		APIConfigFile:    *apiConfig,
		RPCConfigFile:    *rpcConfig,
		Migrate:          utils.MigrateOptions{Enabled: *migrate},
		EnableRPCMonitor: *withMonitor,
	}); err != nil {
		log.Fatal(err)
	}
}
