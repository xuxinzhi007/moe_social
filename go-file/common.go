package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/gin-gonic/gin"
)

const protocolVersion = "2025-03-26"

type jsonRPCRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params"`
}

type session struct {
	id string
}

var (
	baseDir   string
	authToken string
	sessions  sync.Map
)

func envOr(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func authMiddleware(c *gin.Context) {
	if authToken == "" {
		c.Next()
		return
	}
	header := c.GetHeader("Authorization")
	if header != "Bearer "+authToken {
		c.AbortWithStatusJSON(401, gin.H{"error": "unauthorized"})
		return
	}
	c.Next()
}

func newSessionID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func writeJSONRPCError(c *gin.Context, id json.RawMessage, code int, message string) {
	c.JSON(200, gin.H{
		"jsonrpc": "2.0",
		"id":      id,
		"error": gin.H{
			"code":    code,
			"message": message,
		},
	})
}

func toolListFiles(relPath string) (string, bool) {
	dir, err := safePath(relPath)
	if err != nil {
		return err.Error(), true
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err.Error(), true
	}

	type item struct {
		Name  string `json:"name"`
		IsDir bool   `json:"is_dir"`
	}
	items := make([]item, 0, len(entries))
	for _, e := range entries {
		items = append(items, item{Name: e.Name(), IsDir: e.IsDir()})
	}
	b, _ := json.MarshalIndent(items, "", "  ")
	return string(b), false
}

func toolReadFile(relPath string) (string, bool) {
	path, err := safePath(relPath)
	if err != nil {
		return err.Error(), true
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return err.Error(), true
	}
	return string(data), false
}

func toolWriteFile(relPath, content string) (string, bool) {
	path, err := safePath(relPath)
	if err != nil {
		return err.Error(), true
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err.Error(), true
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		return err.Error(), true
	}
	return "file written successfully", false
}

func safePath(relPath string) (string, error) {
	clean := filepath.Clean(filepath.Join(baseDir, relPath))
	root := filepath.Clean(baseDir)
	if clean != root && !strings.HasPrefix(clean, root+string(os.PathSeparator)) {
		return "", fmt.Errorf("path not allowed")
	}
	return clean, nil
}
