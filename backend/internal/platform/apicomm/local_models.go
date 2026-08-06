package apicomm

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"backend/internal/platform/apiconfig"
)

// LocalModelMeta describes one downloadable GGUF entry from server catalog.
type LocalModelMeta struct {
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

// ResolveLocalModelsStorageDir returns absolute storage directory for GGUF files.
func ResolveLocalModelsStorageDir(configured string) (string, error) {
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

// LoadLocalModelCatalog builds catalog items and skips entries whose files are missing.
func LoadLocalModelCatalog(conf apiconfig.LocalModelsConf) ([]LocalModelMeta, error) {
	storageDir, err := ResolveLocalModelsStorageDir(conf.StorageDir)
	if err != nil {
		return nil, err
	}
	if len(conf.Catalog) == 0 {
		return []LocalModelMeta{}, nil
	}

	out := make([]LocalModelMeta, 0, len(conf.Catalog))
	for _, entry := range conf.Catalog {
		meta, err := resolveCatalogEntry(storageDir, entry)
		if err != nil {
			if errors.Is(err, errLocalModelFileMissing) {
				continue
			}
			return nil, err
		}
		out = append(out, meta)
	}
	return out, nil
}

var errLocalModelFileMissing = errors.New("local model file missing")

func resolveCatalogEntry(storageDir string, entry apiconfig.LocalModelCatalogEntry) (LocalModelMeta, error) {
	id := strings.TrimSpace(entry.Id)
	filename := strings.TrimSpace(entry.Filename)
	if id == "" || filename == "" {
		return LocalModelMeta{}, fmt.Errorf("catalog entry requires id and filename")
	}
	if strings.Contains(filename, "..") || strings.ContainsRune(filename, filepath.Separator) {
		return LocalModelMeta{}, fmt.Errorf("invalid filename for catalog id %s", id)
	}

	filePath := filepath.Join(storageDir, filename)
	st, err := os.Stat(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return LocalModelMeta{}, errLocalModelFileMissing
		}
		return LocalModelMeta{}, err
	}
	if st.IsDir() {
		return LocalModelMeta{}, fmt.Errorf("catalog file is directory: %s", filename)
	}

	size := entry.SizeBytes
	if size <= 0 {
		size = st.Size()
	}
	sha := strings.TrimSpace(entry.Sha256)
	if sha == "" {
		sha, err = fileSHA256Hex(filePath)
		if err != nil {
			return LocalModelMeta{}, err
		}
	}

	return LocalModelMeta{
		ID:          id,
		Name:        strings.TrimSpace(entry.Name),
		Filename:    filename,
		FilePath:    filePath,
		SizeBytes:   size,
		Sha256:      strings.ToLower(sha),
		Description: strings.TrimSpace(entry.Description),
		ParametersB: entry.ParametersB,
		Recommended: entry.Recommended,
	}, nil
}

// FindLocalModelByID returns one catalog item by id.
func FindLocalModelByID(conf apiconfig.LocalModelsConf, id string) (LocalModelMeta, error) {
	id = strings.TrimSpace(id)
	if id == "" {
		return LocalModelMeta{}, errors.New("model id is empty")
	}
	items, err := LoadLocalModelCatalog(conf)
	if err != nil {
		return LocalModelMeta{}, err
	}
	for _, item := range items {
		if item.ID == id {
			return item, nil
		}
	}
	return LocalModelMeta{}, fmt.Errorf("local model not found: %s", id)
}

// ParseHTTPByteRange parses a single Range header for file streaming.
func ParseHTTPByteRange(header string, size int64) (int64, int64, error) {
	if !strings.HasPrefix(header, "bytes=") {
		return 0, 0, fmt.Errorf("unsupported range unit")
	}
	spec := strings.TrimPrefix(header, "bytes=")
	parts := strings.Split(spec, "-")
	if len(parts) != 2 {
		return 0, 0, fmt.Errorf("invalid range format")
	}

	var start, end int64
	if parts[0] == "" {
		suffix, err := strconv.ParseInt(parts[1], 10, 64)
		if err != nil || suffix <= 0 {
			return 0, 0, fmt.Errorf("invalid suffix range")
		}
		start = size - suffix
		if start < 0 {
			start = 0
		}
		end = size - 1
	} else {
		var err error
		start, err = strconv.ParseInt(parts[0], 10, 64)
		if err != nil || start < 0 {
			return 0, 0, fmt.Errorf("invalid range start")
		}
		if parts[1] == "" {
			end = size - 1
		} else {
			end, err = strconv.ParseInt(parts[1], 10, 64)
			if err != nil || end < start {
				return 0, 0, fmt.Errorf("invalid range end")
			}
		}
	}

	if start >= size {
		return 0, 0, fmt.Errorf("range start out of bounds")
	}
	if end >= size {
		end = size - 1
	}
	return start, end, nil
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
