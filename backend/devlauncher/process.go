package devlauncher

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

// ManagedProcess is a background dev subprocess with prefixed logs.
type ManagedProcess struct {
	Name string
	Cmd  *exec.Cmd
}

// BuildDevBinary compiles pkg into backend/.dev/<name>.
func BuildDevBinary(root, devBin, name, pkg string) (string, error) {
	if err := os.MkdirAll(devBin, 0o755); err != nil {
		return "", fmt.Errorf("dev bin dir: %w", err)
	}
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

// StartProcess runs bin with args in dir; stdout/stderr are prefixed with [name].
func StartProcess(name, dir, bin string, args ...string) (*ManagedProcess, error) {
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
	return &ManagedProcess{Name: name, Cmd: cmd}, nil
}

func pipeLines(name string, r io.Reader, w io.Writer) {
	prefix := fmt.Sprintf("[%s] ", name)
	sc := bufio.NewScanner(r)
	for sc.Scan() {
		fmt.Fprintf(w, "%s%s\n", prefix, sc.Text())
	}
}

// StopManaged kills a single managed process (and its group on Unix).
func StopManaged(p *ManagedProcess) {
	if p == nil || p.Cmd == nil || p.Cmd.Process == nil {
		return
	}
	pid := p.Cmd.Process.Pid
	log.Printf("[%s] stopping pid=%d", p.Name, pid)
	stopProcessTree(pid)
	_ = p.Cmd.Wait()
}

// StopAllManaged stops processes in reverse start order.
func StopAllManaged(procs []*ManagedProcess) {
	for i := len(procs) - 1; i >= 0; i-- {
		StopManaged(procs[i])
	}
}
