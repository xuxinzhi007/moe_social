//go:build hybrid

package main

import (
	"flag"
	"os"
	"strings"

	"backend/rpc/runserver"
	"backend/utils"
)

var configFile = flag.String("f", "etc/moe.yaml", "the config file")

var migrate = flag.Bool("migrate", false, "run schema migrate before starting RPC")
var migrateModels = flag.String("migrate-models", "", "with -migrate: comma-separated table keys (empty=all)")
var migrateForce = flag.Bool("migrate-force", false, "with -migrate: ignore schema hash cache")

var enableDebug = flag.Bool("debug", false, "expose local debug HTTP API on loopback (dev only; use make rpc-debug)")

func main() {
	flag.Parse()

	s, _, mon, err := runserver.Start(runserver.Options{
		ConfigFile: *configFile,
		Migrate: utils.MigrateOptions{
			Enabled: *migrate,
			Models:  utils.ParseMigrateModelKeys(*migrateModels),
			Force:   *migrateForce,
		},
		EnableMonitor: debugEnabled(),
	})
	if err != nil {
		panic(err)
	}
	defer s.Stop()
	if mon != nil {
		defer mon.Stop()
	}

	s.Start()
}

func debugEnabled() bool {
	if *enableDebug {
		return true
	}
	return strings.EqualFold(strings.TrimSpace(os.Getenv("MOE_RPC_MONITOR")), "on")
}
