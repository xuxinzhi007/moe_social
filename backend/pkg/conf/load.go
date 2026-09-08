package conf

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"

	"github.com/spf13/viper"
)

// searchDirs 与迁移前 20 处读取点使用的候选路径完全一致：
// 进程可能从 backend/、backend/cmd/<tool>/ 或仓库根启动。
var searchDirs = []string{"./config", "../config", "../../config"}

// state 是缓存的加载结果。
//
// 保留原始 *viper.Viper 不是为了让人绕过类型化 Config，而是因为两类语义结构体表达不了：
//  1. IsSet —— 装配开关区分「未设置（继承默认）」与「显式 false」；
//  2. 动态键 —— moe.<domain>_api_in_process 有 19 个同形键，由域名拼出。
//
// 两者都只在 derive.go 内部使用。
type state struct {
	cfg  *Config
	v    *viper.Viper
	path string
}

var (
	mu sync.RWMutex
	// current 只在**成功**加载后赋值。失败时保持 nil，这样启动路径调用 Load 仍能拿到错误。
	current *state
	// autoFailed 记录 Get 已试过且失败，避免热路径每次调用都重新 stat 三个目录。
	autoFailed bool
	autoErr    error
)

// empty 是 Get 在加载失败时返回的零值，
// 与迁移前各读取点「ReadInConfig 失败就用默认值」的宽松行为一致。
var empty = &Config{}

// Get 返回已缓存的配置；首次调用按 searchDirs 解析 config.yaml 并缓存。
//
// 读不到文件时返回零值 Config 而不是 panic，且不再重试。需要感知失败的启动路径请用
// Load（它总会重试并返回错误），或用 Err 观测 Get 吞掉的原因。
func Get() *Config {
	mu.RLock()
	s := current
	failed := autoFailed
	mu.RUnlock()
	if s != nil {
		return s.cfg
	}
	if failed {
		return empty
	}

	mu.Lock()
	defer mu.Unlock()
	if current != nil {
		return current.cfg
	}
	if autoFailed {
		return empty
	}
	if _, err := loadLocked(); err != nil {
		autoFailed = true
		autoErr = err
		return empty
	}
	return current.cfg
}

// Load 加载并缓存配置，返回错误。启动路径用它，好让配置问题在起来之前暴露。
// 已缓存时直接返回缓存，不重复读盘；此前 Get 失败过也会重试。
func Load() (*Config, error) {
	mu.RLock()
	s := current
	mu.RUnlock()
	if s != nil {
		return s.cfg, nil
	}

	mu.Lock()
	defer mu.Unlock()
	if current != nil {
		return current.cfg, nil
	}
	cfg, err := loadLocked()
	if err != nil {
		autoErr = err
		return nil, err
	}
	autoFailed = false
	autoErr = nil
	return cfg, nil
}

// LoadFile 从指定文件加载并缓存，对应 cmd/moe-social 的 -f 覆盖。
func LoadFile(path string) (*Config, error) {
	loaded, err := read(path)
	if err != nil {
		return nil, err
	}
	mu.Lock()
	current = loaded
	autoFailed = false
	autoErr = nil
	mu.Unlock()
	return loaded.cfg, nil
}

// Reload 丢弃缓存并重读当前文件。
// 管理台 ApplyRuntimeConfigPatch 写回 config.yaml 后必须调用，否则改动到重启前都不生效。
func Reload() (*Config, error) {
	mu.Lock()
	path := ""
	if current != nil {
		path = current.path
	}
	current = nil
	autoFailed = false
	mu.Unlock()

	if path == "" {
		return Load()
	}
	return LoadFile(path)
}

// Path 返回实际使用的配置文件绝对路径；未成功加载时为空。
func Path() string {
	Get()
	mu.RLock()
	defer mu.RUnlock()
	if current == nil {
		return ""
	}
	return current.path
}

// Err 返回 Get 自动加载时吞掉的错误（配置文件缺失或解析失败）。
func Err() error {
	Get()
	mu.RLock()
	defer mu.RUnlock()
	return autoErr
}

// IsSet 报告键是否在配置文件中显式出现。供 derive.go 判定装配开关的继承语义。
func IsSet(key string) bool {
	Get()
	mu.RLock()
	s := current
	mu.RUnlock()
	return s != nil && s.v != nil && s.v.IsSet(key)
}

// ResetForTest 清空缓存，仅测试用。
func ResetForTest() {
	mu.Lock()
	current = nil
	autoFailed = false
	autoErr = nil
	mu.Unlock()
}

// loadLocked 解析并缓存配置。调用方必须持有写锁。
func loadLocked() (*Config, error) {
	path, err := resolvePath()
	if err != nil {
		return nil, err
	}
	loaded, err := read(path)
	if err != nil {
		return nil, err
	}
	current = loaded
	return loaded.cfg, nil
}

func resolvePath() (string, error) {
	for _, dir := range searchDirs {
		p := filepath.Join(dir, "config.yaml")
		if _, err := os.Stat(p); err == nil {
			return p, nil
		}
	}
	return "", fmt.Errorf("conf: 未在 %v 找到 config.yaml", searchDirs)
}

func read(path string) (*state, error) {
	v := viper.New()
	v.SetConfigFile(path)
	if err := v.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("conf: 读取 %s 失败: %w", path, err)
	}
	var cfg Config
	if err := v.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("conf: 解析 %s 失败: %w", path, err)
	}
	abs, err := filepath.Abs(v.ConfigFileUsed())
	if err != nil {
		abs = v.ConfigFileUsed()
	}
	return &state{cfg: &cfg, v: v, path: abs}, nil
}
