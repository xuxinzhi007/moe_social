package moelog

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

const slowSQL = 200 * time.Millisecond

type gormLogger struct{}

// GORMLogger 把 SQL 打到终端。普通查询是 DEBUG，慢查询是 WARN，失败是 ERROR。
// 轮询找不到记录时只保留 SQL，不打 record not found。
func GORMLogger() logger.Interface {
	return gormLogger{}
}

func (gormLogger) LogMode(logger.LogLevel) logger.Interface { return gormLogger{} }

func (gormLogger) Info(_ context.Context, msg string, args ...any) {
	Infof(msg, args...)
}

func (gormLogger) Warn(_ context.Context, msg string, args ...any) {
	Warnf(msg, args...)
}

func (gormLogger) Error(_ context.Context, msg string, args ...any) {
	Errorf(msg, args...)
}

func (gormLogger) Trace(_ context.Context, begin time.Time, fc func() (string, int64), err error) {
	sql, rows := fc()
	elapsed := time.Since(begin).Round(time.Millisecond)
	switch {
	case err != nil && !errors.Is(err, gorm.ErrRecordNotFound):
		Errorf("sql err=%v duration=%s rows=%d %s", err, elapsed, rows, sql)
	case elapsed >= slowSQL:
		Warnf("sql slow duration=%s rows=%d %s", elapsed, rows, sql)
	default:
		Debugf("sql duration=%s rows=%d %s", elapsed, rows, sql)
	}
}
