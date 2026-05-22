package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

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
		raw, readErr := os.ReadFile(example)
		if readErr != nil {
			log.Fatalf("config not found: %s\nCopy %s to config.yaml and edit token.", abs, example)
		}
		if writeErr := os.WriteFile(abs, raw, 0o600); writeErr != nil {
			log.Fatalf("config not found: %s\nCopy %s to config.yaml manually: %v", abs, example, writeErr)
		}
		log.Printf("created %s from config.example.yaml — please edit token before production use", abs)
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

	srv := &http.Server{Addr: cfg.Listen, Handler: mux}
	handler.SetRequestShutdown(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := srv.Shutdown(ctx); err != nil {
			log.Printf("shutdown: %v", err)
		}
		log.Printf("Deploy Agent (pid=%d) stopped", os.Getpid())
		os.Exit(0)
	})

	cloud := cfg.TargetByID("cloud")
	log.Printf("Moe Deploy Agent listening on http://%s (pid=%d)", cfg.Listen, os.Getpid())
	log.Printf("workspace=%s backend=%s", cfg.WorkspaceAbs(), cfg.BackendAbs())
	if cloud.IsSSH() {
		log.Printf("cloud SSH %s@%s backend_dir=%s compose=%s",
			cloud.User, cloud.Host, cloud.BackendDir, cloud.ComposeFile)
	}
	log.Printf("Dashboard: http://%s/", cfg.Listen)

	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		fmt.Fprintf(os.Stderr, "server: %v\n", err)
		os.Exit(1)
	}
}
