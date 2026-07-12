package main

import (
	"crypto/sha256"
	"encoding/hex"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/viper"
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
	v := viper.New()
	v.SetConfigFile(configFile)
	if err := v.ReadInConfig(); err != nil {
		alt := filepath.Join("backend", configFile)
		v.SetConfigFile(alt)
		if err2 := v.ReadInConfig(); err2 != nil {
			return "", err
		}
	}

	secret := strings.TrimSpace(v.GetString("auth.access_secret"))
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
