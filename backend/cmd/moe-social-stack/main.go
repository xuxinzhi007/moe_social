// 开发专用：moe-social + 可选 deploy-agent (:19010)。
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
	configFile = flag.String("f", "config/config.yaml", "Unified config (SSOT)")
	apiConfig  = flag.String("f-api", "", "Optional override: API struct fragment YAML")
	migrate    = flag.Bool("migrate", false, "run schema migrate before starting")
	withAgent  = flag.Bool("agent", false, "start deploy-agent on :19010 (optional devtools / deploy proxy)")
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
		Migrate:           utils.MigrateOptions{Enabled: *migrate},
	}); err != nil {
		log.Fatal(err)
	}
}
