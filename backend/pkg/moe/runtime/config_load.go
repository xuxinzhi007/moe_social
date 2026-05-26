package runtime

import (
	"time"

	"backend/pkg/llminference"

	"github.com/spf13/viper"
)

// LoadInferenceFromViper 从 backend/config/config.yaml 读取 llm_inference。
func LoadInferenceFromViper() llminference.Config {
	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")
	if err := v.ReadInConfig(); err != nil {
		return llminference.Config{}
	}
	base := v.GetString("llm_inference.base_url")
	if base == "" {
		base = v.GetString("ollama.base_url")
	}
	style := v.GetString("llm_inference.api_style")
	if style == "" {
		style = v.GetString("ollama.api_style")
	}
	ts := v.GetInt("llm_inference.timeout_seconds")
	if ts <= 0 {
		ts = v.GetInt("ollama.timeout_seconds")
	}
	model := v.GetString("llm_inference.memory_model")
	if model == "" {
		model = v.GetString("ollama.memory_model")
	}
	return llminference.ConfigFrom(base, style, ts, model)
}

// LoadSmartOptsFromViper 读取智能发送调度参数。
func LoadSmartOptsFromViper() SmartOpts {
	opts := DefaultSmartOpts()
	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")
	if err := v.ReadInConfig(); err != nil {
		return opts
	}
	if m := v.GetInt("moe.bot_smart_retry_minutes"); m > 0 {
		opts.RetryIntervalMinutes = m
	}
	if h := v.GetInt("moe.bot_smart_min_interval_hours"); h > 0 {
		opts.MinIntervalHours = h
	}
	return opts
}

// SchedulerOptsWithSmart 扩展调度器选项。
type SchedulerOptsWithSmart struct {
	SchedulerOpts
	Smart SmartOpts
}

// LoadSchedulerOptsFromViper 读取 Bot 调度器配置。
func LoadSchedulerOptsFromViper() SchedulerOptsWithSmart {
	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath("./config")
	v.AddConfigPath("../config")
	v.AddConfigPath("../../config")
	_ = v.ReadInConfig()

	enabled := true
	if v.IsSet("moe.bot_scheduler_enabled") {
		enabled = v.GetBool("moe.bot_scheduler_enabled")
	}
	tickSec := int64(60)
	if s := v.GetInt64("moe.bot_scheduler_tick_seconds"); s > 0 {
		tickSec = s
	}
	return SchedulerOptsWithSmart{
		SchedulerOpts: SchedulerOpts{
			Enabled:      enabled,
			TickInterval: time.Duration(tickSec) * time.Second,
		},
		Smart: LoadSmartOptsFromViper(),
	}
}
