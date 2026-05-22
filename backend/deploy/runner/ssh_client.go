package runner

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
	"time"

	"golang.org/x/crypto/ssh"
)

// ResolveIdentityFile returns configured key or first existing ~/.ssh/id_ed25519|id_rsa.
func ResolveIdentityFile(configured string) string {
	if p := expandHomePath(strings.TrimSpace(configured)); p != "" {
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p
		}
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	for _, name := range []string{"id_ed25519", "id_rsa"} {
		p := filepath.Join(home, ".ssh", name)
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p
		}
	}
	return ""
}

func expandHomePath(p string) string {
	p = strings.TrimSpace(p)
	if p == "" {
		return ""
	}
	if strings.HasPrefix(p, "~/") {
		if home, err := os.UserHomeDir(); err == nil {
			return filepath.Join(home, p[2:])
		}
	}
	return p
}

func sshAuthMethods(password, identityFile string) ([]ssh.AuthMethod, error) {
	var methods []ssh.AuthMethod
	if keyPath := ResolveIdentityFile(identityFile); keyPath != "" {
		keyBytes, err := os.ReadFile(keyPath)
		if err != nil {
			return nil, fmt.Errorf("读取 SSH 私钥 %s: %w", keyPath, err)
		}
		signer, err := ssh.ParsePrivateKey(keyBytes)
		if err != nil {
			return nil, fmt.Errorf("解析 SSH 私钥 %s（若私钥有口令请先用 ssh-agent）: %w", keyPath, err)
		}
		methods = append(methods, ssh.PublicKeys(signer))
	}
	if strings.TrimSpace(password) != "" {
		methods = append(methods, ssh.Password(password))
	}
	if len(methods) == 0 {
		return nil, fmt.Errorf("未配置 SSH：请在 deploy/config.yaml 设置 identity_file（推荐）或 password")
	}
	return methods, nil
}

func dialSSH(ctx context.Context, cfg SSHConfig) (*ssh.Client, error) {
	methods, err := sshAuthMethods(cfg.Password, cfg.IdentityFile)
	if err != nil {
		return nil, err
	}
	port := cfg.Port
	if port <= 0 {
		port = 22
	}
	addr := net.JoinHostPort(cfg.Host, fmt.Sprintf("%d", port))
	dialer := &net.Dialer{Timeout: 20 * time.Second}
	conn, err := dialer.DialContext(ctx, "tcp", addr)
	if err != nil {
		return nil, fmt.Errorf("连接 %s: %w", addr, err)
	}
	sshConn, chans, reqs, err := ssh.NewClientConn(conn, addr, &ssh.ClientConfig{
		User:            cfg.User,
		Auth:            methods,
		HostKeyCallback: ssh.InsecureIgnoreHostKey(), //nolint:gosec // 内网 VPS 运维台
		Timeout:         20 * time.Second,
	})
	if err != nil {
		_ = conn.Close()
		return nil, err
	}
	return ssh.NewClient(sshConn, chans, reqs), nil
}

// runSSHNative runs remote shell script via golang.org/x/crypto/ssh (supports password).
func runSSHNative(ctx context.Context, cfg SSHConfig, remoteScript string, sink LogSink) (exitCode int, err error) {
	client, err := dialSSH(ctx, cfg)
	if err != nil {
		return 255, err
	}
	defer client.Close()

	session, err := client.NewSession()
	if err != nil {
		return -1, err
	}
	defer session.Close()

	stdout, err := session.StdoutPipe()
	if err != nil {
		return -1, err
	}
	stderr, err := session.StderrPipe()
	if err != nil {
		return -1, err
	}

	remoteScript = strings.TrimSpace(remoteScript)
	cmd := remoteScript
	if cmd != "" {
		cmd = "export LANG=C LC_ALL=C; " + cmd
	}

	if sink != nil {
		sink(fmt.Sprintf("$ ssh %s@%s (native)\n", cfg.User, cfg.Host))
	}

	done := make(chan struct{})
	go func() {
		pipeSSHLines(stdout, sink)
		close(done)
	}()
	go pipeSSHLines(stderr, sink)

	runErr := session.Run(cmd)
	<-done

	exitCode = 0
	if runErr != nil {
		if ee, ok := runErr.(*ssh.ExitError); ok {
			exitCode = ee.ExitStatus()
		} else {
			return -1, runErr
		}
	}
	return exitCode, nil
}

func pipeSSHLines(r io.Reader, sink LogSink) {
	if sink == nil {
		return
	}
	sc := bufio.NewScanner(r)
	buf := make([]byte, 0, 64*1024)
	sc.Buffer(buf, 1024*1024)
	for sc.Scan() {
		sink(sc.Text() + "\n")
	}
}
