package runner

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

var deployBuildCacheRoot string

// SetDeployBuildCacheRoot configures an isolated GOCACHE/tmp tree for Deploy Agent jobs.
func SetDeployBuildCacheRoot(root string) {
	deployBuildCacheRoot = strings.TrimSpace(root)
}

// DeployBuildCacheRoot returns the configured cache root (may be empty).
func DeployBuildCacheRoot() string {
	return deployBuildCacheRoot
}

// DeployCachePaths returns GOCACHE and temp dirs under root.
func DeployCachePaths(root string) (goCache, tmpDir string) {
	root = strings.TrimSpace(root)
	return filepath.Join(root, "go-build"), filepath.Join(root, "tmp")
}

// ApplyDeployBuildCache redirects Go cache and process temp dirs away from system TEMP.
func ApplyDeployBuildCache(env []string, root string) []string {
	root = strings.TrimSpace(root)
	if root == "" {
		return env
	}
	goCache, tmpDir := DeployCachePaths(root)
	_ = os.MkdirAll(goCache, 0o755)
	_ = os.MkdirAll(tmpDir, 0o755)

	m := envSliceToMap(env)
	m["GOCACHE"] = goCache
	m["GOTMPDIR"] = tmpDir
	m["TMPDIR"] = tmpDir
	m["TEMP"] = tmpDir
	m["TMP"] = tmpDir
	return envMapToSlice(m)
}

// LinuxCrossBinaries are outputs from backend_build_linux.
var LinuxCrossBinaries = []string{
	"api/moe-social-api",
	"rpc/moe-social-rpc",
}

// BuildCacheArtifact describes a file on disk.
type BuildCacheArtifact struct {
	Path   string `json:"path"`
	Exists bool   `json:"exists"`
	Size   int64  `json:"size_bytes"`
}

// BuildCacheStatus is returned by GET /api/deploy/build-cache.
type BuildCacheStatus struct {
	Root            string               `json:"root"`
	GoCacheDir      string               `json:"go_cache_dir"`
	TmpDir          string               `json:"tmp_dir"`
	CacheBytes      int64                `json:"cache_bytes"`
	LinuxBinaries   []BuildCacheArtifact `json:"linux_binaries"`
	BinaryBytes     int64                `json:"binary_bytes"`
	TotalReclaimable int64               `json:"total_reclaimable_bytes"`
}

// BuildCacheInfo inspects cache dirs and optional linux binaries under backendDir.
func BuildCacheInfo(cacheRoot, backendDir string) (BuildCacheStatus, error) {
	st := BuildCacheStatus{Root: cacheRoot}
	if cacheRoot != "" {
		st.GoCacheDir, st.TmpDir = DeployCachePaths(cacheRoot)
		n, err := dirSize(cacheRoot)
		if err != nil {
			return st, err
		}
		st.CacheBytes = n
	}
	for _, rel := range LinuxCrossBinaries {
		full := filepath.Join(backendDir, filepath.FromSlash(rel))
		art := BuildCacheArtifact{Path: rel}
		if info, err := os.Stat(full); err == nil && !info.IsDir() {
			art.Exists = true
			art.Size = info.Size()
			st.BinaryBytes += art.Size
		}
		st.LinuxBinaries = append(st.LinuxBinaries, art)
	}
	st.TotalReclaimable = st.CacheBytes + st.BinaryBytes
	return st, nil
}

// CleanBuildCache removes cache tree and optionally linux cross-compile outputs.
func CleanBuildCache(cacheRoot, backendDir string, removeBinaries bool) (freed int64, err error) {
	if cacheRoot != "" {
		n, err := dirSize(cacheRoot)
		if err != nil {
			return 0, err
		}
		if err := os.RemoveAll(cacheRoot); err != nil {
			return 0, fmt.Errorf("清理编译缓存目录: %w", err)
		}
		freed += n
	}
	if removeBinaries {
		for _, rel := range LinuxCrossBinaries {
			full := filepath.Join(backendDir, filepath.FromSlash(rel))
			info, statErr := os.Stat(full)
			if statErr != nil {
				continue
			}
			if info.IsDir() {
				continue
			}
			if err := os.Remove(full); err != nil {
				return freed, fmt.Errorf("删除 %s: %w", rel, err)
			}
			freed += info.Size()
		}
	}
	return freed, nil
}

func dirSize(root string) (int64, error) {
	var total int64
	err := filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			if os.IsNotExist(err) {
				return nil
			}
			return err
		}
		if d.IsDir() {
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		total += info.Size()
		return nil
	})
	if os.IsNotExist(err) {
		return 0, nil
	}
	return total, err
}
