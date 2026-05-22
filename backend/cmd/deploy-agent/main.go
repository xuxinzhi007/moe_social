package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"

	deploycfg "backend/deploy/config"
	"backend/deploy/handler"
)

func main() {
	configPath := flag.String("f", "deploy/config.yaml", "deploy agent config file")
	flag.Parse()

	abs, err := filepath.Abs(*configPath)
	if err != nil {
		log.Fatalf("config path: %v", err)
	}
	if _, err := os.Stat(abs); os.IsNotExist(err) {
		example := filepath.Join(filepath.Dir(abs), "config.example.yaml")
		log.Fatalf("config not found: %s\nCopy %s to config.yaml and edit token.", abs, example)
	}

	cfg, err := deploycfg.Load(abs)
	if err != nil {
		log.Fatalf("load config: %v", err)
	}
	cfg.EnvOverride()

	h := handler.New(cfg)
	mux := http.NewServeMux()
	h.RegisterRoutes(mux)
	handler.MountDashboard(mux, cfg.WorkspaceAbs())

	log.Printf("Moe Deploy Agent listening on http://%s", cfg.Listen)
	log.Printf("workspace=%s backend=%s", cfg.WorkspaceAbs(), cfg.BackendAbs())
	log.Printf("Dashboard: http://%s/  (copy deploy/config.example.yaml -> config.yaml)", cfg.Listen)

	if err := http.ListenAndServe(cfg.Listen, mux); err != nil {
		fmt.Fprintf(os.Stderr, "server: %v\n", err)
		os.Exit(1)
	}
}
