package runtime

import (
	"backend/pkg/conf"
)

// LoadSmartOpts 读取智能发送调度参数。
// 序4：此前这里自己开 viper 并硬编码 searchDirs，因此看不见 cmd/moe-social 的 -f。
func LoadSmartOpts() SmartOpts {
	opts := DefaultSmartOpts()
	retry, minInterval := conf.SmartRetry()
	if retry > 0 {
		opts.RetryIntervalMinutes = retry
	}
	if minInterval > 0 {
		opts.MinIntervalHours = minInterval
	}
	return opts
}

// SchedulerOptsWithSmart 扩展调度器选项。
type SchedulerOptsWithSmart struct {
	SchedulerOpts
	Smart SmartOpts
}

// LoadSchedulerOpts 读取 Bot 调度器配置。
func LoadSchedulerOpts() SchedulerOptsWithSmart {
	enabled, tick := conf.BotScheduler()
	return SchedulerOptsWithSmart{
		SchedulerOpts: SchedulerOpts{
			Enabled:      enabled,
			TickInterval: tick,
		},
		Smart: LoadSmartOpts(),
	}
}
