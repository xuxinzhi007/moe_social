// Package yamlconf 从 YAML 片段加载配置（P5-D 替代 go-zero conf）。
package yamlconf

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

// MustLoad 读取 path 并反序列化到 v；失败 panic（与 go-zero conf.MustLoad 行为一致）。
func MustLoad(path string, v any) {
	if err := Load(path, v); err != nil {
		panic(err)
	}
}

// Load 读取 path 并反序列化到 v。
func Load(path string, v any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("yamlconf load %s: %w", path, err)
	}
	if err := yaml.Unmarshal(data, v); err != nil {
		return fmt.Errorf("yamlconf unmarshal %s: %w", path, err)
	}
	return nil
}
