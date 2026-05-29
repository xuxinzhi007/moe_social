package brain

import (
	"fmt"
	"strings"
	"time"

	"github.com/robfig/cron/v3"
	"github.com/spf13/viper"
	"gorm.io/gorm"
)

const defaultDreamCron = "0 4 * * *"

// DefaultDreamCron 默认入梦 cron（每天 04:00）。
func DefaultDreamCron() string {
	return defaultDreamCron
}

func validateDreamCron(expr string) error {
	expr = strings.TrimSpace(expr)
	if expr == "" {
		return fmt.Errorf("cron 表达式不能为空")
	}
	_, err := cron.ParseStandard(expr)
	return err
}

func nextDreamCronRun(expr string, from time.Time) (time.Time, error) {
	sched, err := cron.ParseStandard(strings.TrimSpace(expr))
	if err != nil {
		return time.Time{}, err
	}
	return sched.Next(from), nil
}

func dreamDue(nextDreamAt string, now time.Time) bool {
	nextDreamAt = strings.TrimSpace(nextDreamAt)
	if nextDreamAt == "" {
		return true
	}
	t, err := time.ParseInLocation("2006-01-02 15:04:05", nextDreamAt, time.Local)
	if err != nil {
		return true
	}
	return !t.After(now)
}

// UpdateDreamSchedule 更新入梦 cron 并刷新 next_dream_at。
func UpdateDreamSchedule(db *gorm.DB, agentKey string, enabled bool, cronExpr string) (RpgConfig, error) {
	cfg := loadRpgConfig(db, agentKey)
	cfg.DreamEnabled = enabled
	cronExpr = strings.TrimSpace(cronExpr)
	if enabled {
		if cronExpr == "" {
			cronExpr = defaultDreamCron
		}
		if err := validateDreamCron(cronExpr); err != nil {
			return RpgConfig{}, err
		}
		cfg.DreamCron = cronExpr
		next, err := nextDreamCronRun(cronExpr, time.Now())
		if err != nil {
			return RpgConfig{}, err
		}
		cfg.NextDreamAt = next.Format("2006-01-02 15:04:05")
	} else {
		if cronExpr != "" {
			cfg.DreamCron = cronExpr
		}
		cfg.NextDreamAt = ""
	}
	if err := saveRpgConfig(db, agentKey, cfg); err != nil {
		return RpgConfig{}, err
	}
	return cfg, nil
}

// DreamSchedulerOpts 定时入梦调度。
type DreamSchedulerOpts struct {
	Enabled      bool
	TickInterval time.Duration
}

// LoadDreamSchedulerOptsFromViper 读取 moe.dream_scheduler_*。
func LoadDreamSchedulerOptsFromViper() DreamSchedulerOpts {
	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")
	_ = v.ReadInConfig()

	enabled := true
	if v.IsSet("moe.dream_scheduler_enabled") {
		enabled = v.GetBool("moe.dream_scheduler_enabled")
	}
	tickSec := int64(300)
	if s := v.GetInt64("moe.dream_scheduler_tick_seconds"); s > 0 {
		tickSec = s
	}
	return DreamSchedulerOpts{
		Enabled:      enabled,
		TickInterval: time.Duration(tickSec) * time.Second,
	}
}

// LoadRpgConfigFromDB 读取 agent 的 RPG config_json。
func LoadRpgConfigFromDB(db *gorm.DB, agentKey string) RpgConfig {
	return loadRpgConfig(db, agentKey)
}

// SaveRpgConfig 写回 agent RPG config_json。
func SaveRpgConfig(db *gorm.DB, agentKey string, cfg RpgConfig) error {
	return saveRpgConfig(db, agentKey, cfg)
}

// DreamDue 是否到达入梦时间。
func DreamDue(nextDreamAt string, now time.Time) bool {
	return dreamDue(nextDreamAt, now)
}

// NextDreamCronRun 计算下次 cron 触发时间。
func NextDreamCronRun(expr string, from time.Time) (time.Time, error) {
	return nextDreamCronRun(expr, from)
}
