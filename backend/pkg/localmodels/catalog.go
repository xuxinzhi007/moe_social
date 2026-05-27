// Package localmodels 本地 GGUF 模型目录（与 API 层解耦）。
package localmodels

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// CatalogEntry 配置清单条目。
type CatalogEntry struct {
	ID          string  `mapstructure:"id" yaml:"id"`
	Name        string  `mapstructure:"name" yaml:"name"`
	Filename    string  `mapstructure:"filename" yaml:"filename"`
	SizeBytes   int64   `mapstructure:"size_bytes" yaml:"size_bytes"`
	Sha256      string  `mapstructure:"sha256" yaml:"sha256"`
	Description string  `mapstructure:"description" yaml:"description"`
	ParametersB float64 `mapstructure:"parameters_b" yaml:"parameters_b"`
	Recommended bool    `mapstructure:"recommended" yaml:"recommended"`
}

// Meta 解析后的本地模型元数据。
type Meta struct {
	ID          string
	Name        string
	Filename    string
	FilePath    string
	SizeBytes   int64
	Sha256      string
	Description string
	ParametersB float64
	Recommended bool
}

var errFileMissing = errors.New("local model file missing")

// ResolveStorageDir 解析 GGUF 存储目录绝对路径。
func ResolveStorageDir(configured string) (string, error) {
	dir := strings.TrimSpace(configured)
	if dir == "" {
		dir = "data/local_models"
	}
	if !filepath.IsAbs(dir) {
		candidates := []string{
			filepath.Join("..", dir),
			filepath.Join("../..", dir),
			dir,
		}
		for _, candidate := range candidates {
			if st, err := os.Stat(candidate); err == nil && st.IsDir() {
				abs, err := filepath.Abs(candidate)
				if err == nil {
					return abs, nil
				}
				return candidate, nil
			}
		}
		abs, err := filepath.Abs(dir)
		if err != nil {
			return "", fmt.Errorf("resolve local models dir: %w", err)
		}
		return abs, nil
	}
	return dir, nil
}

// LoadCatalog 加载存在文件的目录项，跳过缺失文件。
func LoadCatalog(storageDir string, entries []CatalogEntry) ([]Meta, error) {
	dir, err := ResolveStorageDir(storageDir)
	if err != nil {
		return nil, err
	}
	if len(entries) == 0 {
		return []Meta{}, nil
	}
	out := make([]Meta, 0, len(entries))
	for _, entry := range entries {
		meta, err := resolveEntry(dir, entry)
		if err != nil {
			if errors.Is(err, errFileMissing) {
				continue
			}
			return nil, err
		}
		out = append(out, meta)
	}
	return out, nil
}

// FindByID 按 id 查找目录项。
func FindByID(storageDir string, entries []CatalogEntry, id string) (Meta, error) {
	id = strings.TrimSpace(id)
	if id == "" {
		return Meta{}, errors.New("model id is empty")
	}
	items, err := LoadCatalog(storageDir, entries)
	if err != nil {
		return Meta{}, err
	}
	for _, item := range items {
		if item.ID == id {
			return item, nil
		}
	}
	return Meta{}, fmt.Errorf("local model not found: %s", id)
}

func resolveEntry(storageDir string, entry CatalogEntry) (Meta, error) {
	id := strings.TrimSpace(entry.ID)
	filename := strings.TrimSpace(entry.Filename)
	if id == "" || filename == "" {
		return Meta{}, fmt.Errorf("catalog entry requires id and filename")
	}
	if strings.Contains(filename, "..") || strings.ContainsRune(filename, filepath.Separator) {
		return Meta{}, fmt.Errorf("invalid filename for catalog id %s", id)
	}
	filePath := filepath.Join(storageDir, filename)
	st, err := os.Stat(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return Meta{}, errFileMissing
		}
		return Meta{}, err
	}
	if st.IsDir() {
		return Meta{}, fmt.Errorf("catalog file is directory: %s", filename)
	}
	size := entry.SizeBytes
	if size <= 0 {
		size = st.Size()
	}
	sha := strings.TrimSpace(entry.Sha256)
	if sha == "" {
		sha, err = fileSHA256Hex(filePath)
		if err != nil {
			return Meta{}, err
		}
	}
	name := strings.TrimSpace(entry.Name)
	if name == "" {
		name = id
	}
	return Meta{
		ID:          id,
		Name:        name,
		Filename:    filename,
		FilePath:    filePath,
		SizeBytes:   size,
		Sha256:      strings.ToLower(sha),
		Description: strings.TrimSpace(entry.Description),
		ParametersB: entry.ParametersB,
		Recommended: entry.Recommended,
	}, nil
}

func fileSHA256Hex(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}
