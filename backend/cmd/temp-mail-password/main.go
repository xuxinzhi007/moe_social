package main

import (
	"crypto/sha256"
	"encoding/hex"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"backend/pkg/conf"
)

func main() {
	var (
		email      string
		configFile string
		jsonOutput bool
	)

	flag.StringVar(&email, "email", "", "Temporary mailbox address")
	flag.StringVar(&configFile, "f", "config/config.yaml", "Unified config file")
	flag.BoolVar(&jsonOutput, "json", false, "Print JSON output")
	flag.Parse()

	if strings.TrimSpace(email) == "" && flag.NArg() > 0 {
		email = flag.Arg(0)
	}
	email = strings.ToLower(strings.TrimSpace(email))
	if email == "" || !strings.Contains(email, "@") {
		exitf("invalid email, use -email user@example.com")
	}

	secret, err := loadAccessSecret(configFile)
	if err != nil {
		exitf("load config failed: %v", err)
	}

	password := tempMailboxPassword(email, secret)
	if jsonOutput {
		fmt.Printf("{\"email\":\"%s\",\"password\":\"%s\"}\n", email, password)
		return
	}

	fmt.Printf("email: %s\npassword: %s\n", email, password)
}

func loadAccessSecret(configFile string) (string, error) {
	// -f 指定文件，所以用 LoadFile；失败时按原逻辑再试 backend/ 前缀（从仓库根启动的情况）。
	if _, err := conf.LoadFile(configFile); err != nil {
		if _, err2 := conf.LoadFile(filepath.Join("backend", configFile)); err2 != nil {
			return "", err
		}
	}

	// 只取文件值，不用 conf.AuthAccessSecret()：这是邮箱口令的派生种子，必须与
	// internal/service/user/user_temp_mail.go 的 tempMailboxPassword 完全一致。
	// 让 MOE_AUTH_ACCESS_SECRET 参与会导致设置该环境变量后既有临时邮箱全部失效。
	secret := strings.TrimSpace(conf.Get().Auth.AccessSecret)
	if secret == "" {
		secret = "moe-social-temp-mail"
	}
	return secret, nil
}

func tempMailboxPassword(email string, secret string) string {
	sum := sha256.Sum256([]byte(strings.ToLower(email) + "|" + secret))
	return hex.EncodeToString(sum[:16])
}

func exitf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}
