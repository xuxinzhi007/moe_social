package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"time"

	"backend/deploy/browser"
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

	if mode, bash, label := deploycfg.WindowsShellLabel(cfg); runtime.GOOS == "windows" && label != "" {
		log.Printf("Windows 本机 shell: %s", label)
		if mode == "cmd" && bash == "" {
			log.Printf("hint: 若本机终端找不到 go，请安装 Git for Windows 或设置 windows_shell: git-bash / local_path_extra")
		}
	}

	h := handler.New(cfg)
	mux := http.NewServeMux()
	h.RegisterRoutes(mux)
	handler.MountDevHub(mux, cfg.WorkspaceAbs(), cfg.RpcDebugUpstream)

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
		log.Printf("已配置远程部署目标 cloud（启动时不连接）: %s@%s backend_dir=%s compose=%s",
			cloud.User, cloud.Host, cloud.BackendDir, cloud.ComposeFile)
	}
	base := "http://" + cfg.Listen
	log.Printf("Moe Admin: http://127.0.0.1:5173/ops/  (cd moe-admin && npm run dev)")
	if browser.ShouldOpen() {
		openURL := base + handler.DashboardPath(cfg.WorkspaceAbs())
		go func(url string) {
			time.Sleep(400 * time.Millisecond)
			if err := browser.Open(url); err != nil {
				log.Printf("open browser: %v (open manually: %s)", err, url)
			}
		}(openURL)
	}

	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		fmt.Fprintf(os.Stderr, "server: %v\n", err)
		os.Exit(1)
	}
}
