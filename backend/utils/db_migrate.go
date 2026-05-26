package utils

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"log"
	"sort"
	"strings"
	"sync"
	"time"

	"backend/model"

	"gorm.io/gorm"
	"gorm.io/gorm/schema"
)

// MigrateOptions 控制 AutoMigrate 行为。
type MigrateOptions struct {
	Enabled bool
	// Models 为空表示全量；否则只迁移匹配的 Key（如 users、moe_agent_runtimes）。
	Models []string
	// Force 为 true 时忽略 schema hash 缓存，强制每张表执行 AutoMigrate。
	Force bool
}

// ParseMigrateModelKeys 解析逗号分隔的 migrate key 列表（空字符串表示全量）。
func ParseMigrateModelKeys(csv string) []string {
	csv = strings.TrimSpace(csv)
	if csv == "" {
		return nil
	}
	parts := strings.Split(csv, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

// RunAutoMigrate 按表串行迁移，并通过 schema hash 跳过未变更表。
func RunAutoMigrate(db *gorm.DB, opts MigrateOptions) error {
	if db == nil {
		return fmt.Errorf("db is nil")
	}

	entries := filterMigrateEntries(opts.Models)
	if len(entries) == 0 {
		return fmt.Errorf("no migrate entries matched models filter")
	}

	start := time.Now()
	if err := db.AutoMigrate(&model.GormSchemaVersion{}); err != nil {
		return fmt.Errorf("ensure gorm_schema_versions: %w", err)
	}

	var migrated, skipped int
	for _, entry := range entries {
		tableName, modelHash, err := computeModelHash(db, entry.Model)
		if err != nil {
			return fmt.Errorf("hash %s: %w", entry.Key, err)
		}

		if !opts.Force && schemaHashMatches(db, tableName, modelHash) {
			skipped++
			log.Printf("migrate skip %s (%s, unchanged)", entry.Key, tableName)
			continue
		}

		t0 := time.Now()
		if err := db.AutoMigrate(entry.Model); err != nil {
			return fmt.Errorf("migrate %s (%s): %w", entry.Key, tableName, err)
		}
		if err := upsertSchemaHash(db, tableName, modelHash); err != nil {
			return fmt.Errorf("record schema hash %s: %w", tableName, err)
		}
		migrated++
		log.Printf("migrate ok   %s (%s, %s)", entry.Key, tableName, time.Since(t0).Round(time.Millisecond))
	}

	log.Printf(
		"schema migrate done: migrated=%d skipped=%d total=%d elapsed=%s",
		migrated, skipped, len(entries), time.Since(start).Round(time.Millisecond),
	)
	return nil
}

func filterMigrateEntries(keys []string) []MigrateEntry {
	all := MigrateModelRegistry()
	if len(keys) == 0 {
		return all
	}
	want := make(map[string]struct{}, len(keys))
	for _, k := range keys {
		k = strings.TrimSpace(strings.ToLower(k))
		if k == "" {
			continue
		}
		want[k] = struct{}{}
	}
	out := make([]MigrateEntry, 0, len(keys))
	for _, e := range all {
		if _, ok := want[strings.ToLower(e.Key)]; ok {
			out = append(out, e)
		}
	}
	return out
}

func computeModelHash(db *gorm.DB, modelValue interface{}) (tableName, hash string, err error) {
	s, err := schema.Parse(modelValue, &sync.Map{}, db.NamingStrategy)
	if err != nil {
		return "", "", err
	}

	parts := make([]string, 0, len(s.Fields))
	for _, f := range s.Fields {
		if f.IgnoreMigration {
			continue
		}
		tag := strings.TrimSpace(f.Tag.Get("gorm"))
		parts = append(parts, fmt.Sprintf("%s:%s:%s:%s", f.Name, f.DBName, f.DataType, tag))
	}
	sort.Strings(parts)

	sum := sha256.Sum256([]byte(s.Table + "|" + strings.Join(parts, ";")))
	return s.Table, hex.EncodeToString(sum[:16]), nil
}

func schemaHashMatches(db *gorm.DB, tableName, modelHash string) bool {
	var row model.GormSchemaVersion
	err := db.Where("table_name = ?", tableName).First(&row).Error
	return err == nil && row.ModelHash == modelHash
}

func upsertSchemaHash(db *gorm.DB, tableName, modelHash string) error {
	row := model.GormSchemaVersion{
		TableName: tableName,
		ModelHash: modelHash,
		UpdatedAt: time.Now(),
	}
	return db.Save(&row).Error
}
