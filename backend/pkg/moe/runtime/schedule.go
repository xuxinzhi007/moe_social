package runtime

import (
	"fmt"
	"strings"
	"time"

	"github.com/robfig/cron/v3"
)

const (
	ScheduleManual = "manual"
	ScheduleCron   = "cron"
	ScheduleSmart  = "smart"
)

// NormalizeScheduleMode 发帖调度模式（manual=仅手动；cron=定时 AI 发帖；smart=LLM 决策后 AI 发帖）。
func NormalizeScheduleMode(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case ScheduleCron, "scheduled", "schedule":
		return ScheduleCron
	case ScheduleSmart, "intelligent", "auto", "ai":
		return ScheduleSmart
	default:
		return ScheduleManual
	}
}

// ValidateScheduleCron 校验标准 5 段 cron（分 时 日 月 周）。
func ValidateScheduleCron(expr string) error {
	expr = strings.TrimSpace(expr)
	if expr == "" {
		return fmt.Errorf("cron 表达式不能为空")
	}
	_, err := cron.ParseStandard(expr)
	return err
}

// NextCronRun 计算 strictly after `from` 的下一次触发时间。
func NextCronRun(expr string, from time.Time) (time.Time, error) {
	sched, err := cron.ParseStandard(strings.TrimSpace(expr))
	if err != nil {
		return time.Time{}, err
	}
	next := sched.Next(from)
	if next.IsZero() {
		return time.Time{}, fmt.Errorf("无法计算下次执行时间")
	}
	return next, nil
}

// ApplyScheduleFields 根据模式写入 cron / next_run_at。
func ApplyScheduleFields(mode, cronExpr string, from time.Time) (string, string, *time.Time, error) {
	mode = NormalizeScheduleMode(mode)
	cronExpr = strings.TrimSpace(cronExpr)
	switch mode {
	case ScheduleManual:
		return mode, "", nil, nil
	case ScheduleSmart:
		if cronExpr != "" {
			if err := ValidateScheduleCron(cronExpr); err != nil {
				return "", "", nil, err
			}
			next, err := NextCronRun(cronExpr, from)
			if err != nil {
				return "", "", nil, err
			}
			return mode, cronExpr, &next, nil
		}
		// 无 cron 时立即进入评估队列（调度器按 retry 间隔轮询）
		next := from
		return mode, "", &next, nil
	case ScheduleCron:
		if err := ValidateScheduleCron(cronExpr); err != nil {
			return "", "", nil, err
		}
		next, err := NextCronRun(cronExpr, from)
		if err != nil {
			return "", "", nil, err
		}
		return mode, cronExpr, &next, nil
	default:
		return ScheduleManual, "", nil, nil
	}
}
