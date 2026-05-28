// 开发专用：在 cmd/moe-social 基础上附加 deploy-agent (:19010) 与 RPC debug (:19011)。
//
//	make moe-social-dev
//	go run ./cmd/moe-social-stack
//
// 生产请用 cmd/moe-social 或 make moe-social。
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
	configFile  = flag.String("f", "config/config.yaml", "Unified config (SSOT)")
	apiConfig   = flag.String("f-api", "", "Optional override: API struct fragment YAML")
	rpcConfig   = flag.String("f-rpc", "", "Optional override: RPC struct fragment YAML")
	migrate     = flag.Bool("migrate", false, "run schema migrate before starting")
	withAgent   = flag.Bool("agent", true, "start deploy-agent on :19010 (devtools / deploy proxy)")
	withMonitor = flag.Bool("monitor", true, "RPC debug API on :19011 for moe-admin RPC monitor")
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
		UnifiedConfigFile: *configFile,
		APIConfigFile:     *apiConfig,
		RPCConfigFile:     *rpcConfig,
		Migrate:           utils.MigrateOptions{Enabled: *migrate},
		EnableRPCMonitor:  *withMonitor,
	}); err != nil {
		log.Fatal(err)
	}
}
