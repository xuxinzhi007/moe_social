// Moe 本地开发启动器：一条命令启动 RPC + API + deploy-agent（可选文档站）。
package main

import (
	"backend/devlauncher"
	"backend/devports"
	"bufio"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
)

var (
	migrate   = flag.Bool("migrate", false, "run schema migrate (make db-migrate) before starting RPC/API")
	withDocs  = flag.Bool("docs", true, "start docs static server on :19012 (python -m http.server)")
	withAgent   = flag.Bool("agent", true, "start deploy-agent on :19010 (same as make deploy-agent)")
	withMonitor = flag.Bool("monitor", true, "RPC process with -debug (:19011) for moe-admin RPC 监控")
)

type managedProc struct {
	name string
	cmd  *exec.Cmd
}

func main() {
	flag.Parse()

	root, err := findBackendRoot()
	if err != nil {
		log.Fatal(err)
	}

	log.Printf("backend root: %s", root)
	log.Print("starting RPC, API" + monitorHint() + agentHint() + docsHint())

	procs, err := startAll(root)
	if err != nil {
		log.Fatalf("start: %v", err)
	}

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)

	exitCh := make(chan struct{}, 1)
	go func() {
		if waitAny(procs) {
			log.Print("a service exited unexpectedly, stopping the rest...")
		}
		exitCh <- struct{}{}
	}()

	select {
	case <-sigCh:
		log.Print("shutting down all backend services...")
	case <-exitCh:
	}

	stopAll(procs)
	log.Print("all backend services stopped")
}

func monitorHint() string {
	if *withMonitor {
		return ", RPC monitor (:" + devports.RpcDebugPortStr() + ")"
	}
	return ""
}

func agentHint() string {
	if *withAgent {
		return ", deploy-agent (:" + devports.AgentPortStr() + ")"
	}
	return ""
}

func docsHint() string {
	if *withDocs {
		return ", docs (:" + devports.DocsStaticPortStr() + ")"
	}
	return ""
}

func startAll(root string) ([]*managedProc, error) {
	var procs []*managedProc

	devBin := filepath.Join(root, ".dev")
	if err := os.MkdirAll(devBin, 0o755); err != nil {
		return nil, fmt.Errorf("dev bin dir: %w", err)
	}

	rpcBin, err := buildDevBinary(root, devBin, "moe-rpc", "./rpc")
	if err != nil {
		return nil, fmt.Errorf("build rpc: %w", err)
	}
	if *migrate {
		if err := runMigrate(root); err != nil {
			log.Fatalf("migrate: %v", err)
		}
	}

	rpcArgs := []string{"-f", "rpc/etc/super.yaml"}
	if *withMonitor {
		rpcArgs = append(rpcArgs, "-debug")
	}
	rpc, err := startProc("rpc", root, rpcBin, rpcArgs...)
	if err != nil {
		stopAll(procs)
		return nil, fmt.Errorf("rpc: %w", err)
	}
	procs = append(procs, rpc)

	apiBin, err := buildDevBinary(root, devBin, "moe-api", "./api")
	if err != nil {
		stopAll(procs)
		return nil, fmt.Errorf("build api: %w", err)
	}
	api, err := startProc("api", root, apiBin, "-f", "api/etc/super.yaml")
	if err != nil {
		stopAll(procs)
		return nil, fmt.Errorf("api: %w", err)
	}
	procs = append(procs, api)

	if *withAgent {
		agent, err := devlauncher.StartDeployAgent(root)
		if err != nil {
			log.Printf("deploy-agent: %v (skip agent)", err)
		} else {
			procs = append(procs, &managedProc{name: agent.Name, cmd: agent.Cmd})
		}
	}

	if *withDocs {
		docsDir := filepath.Join(root, "..", "docs")
		py, pyArgs, err := docsServerCommand(docsDir)
		if err != nil {
			log.Printf("docs: %v (skip docs server)", err)
		} else {
			docs, err := startProc("docs", docsDir, py, pyArgs...)
			if err != nil {
				log.Printf("docs: %v (skip docs server)", err)
			} else {
				procs = append(procs, docs)
			}
		}
	}

	ready := "ready — RPC :8080, API :8888"
	if *withMonitor {
		ready += ", RPC monitor http://" + devports.RpcDebugAddr + "/debug/live"
	}
	if *withAgent {
		ready += ", Agent " + devports.AgentURL()
	} else {
		ready += " (Agent 未启: make deploy-agent 或 go run ./cmd/dev -agent=true)"
	}
	log.Print(ready)
	log.Print("press Ctrl+C to stop all services")
	return procs, nil
}

func runMigrate(root string) error {
	log.Print("running schema migrate ...")
	cmd := exec.Command(goExecutable(), "run", "./cmd/migrate")
	cmd.Dir = root
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func buildDevBinary(root, devBin, name, pkg string) (string, error) {
	out := filepath.Join(devBin, name+exeSuffix())
	log.Printf("building %s ...", name)
	cmd := exec.Command(goExecutable(), "build", "-o", out, pkg)
	cmd.Dir = root
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return "", err
	}
	return out, nil
}

func exeSuffix() string {
	if runtime.GOOS == "windows" {
		return ".exe"
	}
	return ""
}

func goExecutable() string {
	if exe := strings.TrimSpace(os.Getenv("GOEXE")); exe != "" {
		return exe
	}
	return "go"
}

func docsServerCommand(docsDir string) (string, []string, error) {
	if _, err := os.Stat(docsDir); err != nil {
		return "", nil, fmt.Errorf("docs dir missing: %s", docsDir)
	}
	port := devports.DocsStaticPortStr()
	for _, candidate := range []struct {
		bin  string
		args []string
	}{
		{"python", []string{"-m", "http.server", port}},
		{"python3", []string{"-m", "http.server", port}},
		{"py", []string{"-m", "http.server", port}},
	} {
		if path, err := exec.LookPath(candidate.bin); err == nil {
			return path, candidate.args, nil
		}
	}
	return "", nil, errors.New("python not found in PATH")
}

func startProc(name, dir, bin string, args ...string) (*managedProc, error) {
	cmd := exec.Command(bin, args...)
	cmd.Dir = dir
	cmd.Env = os.Environ()
	cmd.SysProcAttr = procSysAttr()

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return nil, err
	}

	if err := cmd.Start(); err != nil {
		return nil, err
	}

	go pipeLines(name, stdout, os.Stdout)
	go pipeLines(name, stderr, os.Stderr)

	log.Printf("[%s] started pid=%d", name, cmd.Process.Pid)
	return &managedProc{name: name, cmd: cmd}, nil
}

func pipeLines(name string, r io.Reader, w io.Writer) {
	prefix := fmt.Sprintf("[%s] ", name)
	sc := bufio.NewScanner(r)
	for sc.Scan() {
		fmt.Fprintf(w, "%s%s\n", prefix, sc.Text())
	}
}

func waitAny(procs []*managedProc) bool {
	if len(procs) == 0 {
		return false
	}
	done := make(chan *managedProc, len(procs))
	for _, p := range procs {
		go func(mp *managedProc) {
			if err := mp.cmd.Wait(); err != nil {
				log.Printf("[%s] exited: %v", mp.name, err)
			} else {
				log.Printf("[%s] exited", mp.name)
			}
			done <- mp
		}(p)
	}
	<-done
	return true
}

func stopAll(procs []*managedProc) {
	for i := len(procs) - 1; i >= 0; i-- {
		killTree(procs[i])
	}
	for _, p := range procs {
		_ = p.cmd.Wait()
	}
}

func killTree(p *managedProc) {
	if p == nil || p.cmd.Process == nil {
		return
	}
	pid := p.cmd.Process.Pid
	log.Printf("[%s] stopping pid=%d", p.name, pid)
	stopProcessTree(pid)
}

func findBackendRoot() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for {
		if isBackendRoot(dir) {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", errors.New("backend root not found (no go.mod with api/super.go); run from backend/ or repo root")
		}
		dir = parent
	}
}

func isBackendRoot(dir string) bool {
	if _, err := os.Stat(filepath.Join(dir, "go.mod")); err != nil {
		return false
	}
	if _, err := os.Stat(filepath.Join(dir, "api", "super.go")); err != nil {
		return false
	}
	if _, err := os.Stat(filepath.Join(dir, "rpc", "super.go")); err != nil {
		return false
	}
	return true
}
