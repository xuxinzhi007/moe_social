// Package moelog 替代 go-zero logx（P5-D 零 go-zero）。
package moelog

import (
	"context"
	"fmt"
	"log"
)

// Info 结构化信息日志。
func Info(msg string, keysAndValues ...any) {
	log.Printf("[INFO] %s %s", msg, kv(keysAndValues...))
}

// Error 错误日志。
func Error(msg string, keysAndValues ...any) {
	log.Printf("[ERROR] %s %s", msg, kv(keysAndValues...))
}

// Infof printf 风格（迁移自 logx.Infof）。
func Infof(format string, args ...any) {
	log.Printf("[INFO] "+format, args...)
}

// Errorf printf 风格（迁移自 logx.Errorf）。
func Errorf(format string, args ...any) {
	log.Printf("[ERROR] "+format, args...)
}

// Debugf printf 风格（迁移自 logx.Debugf）。
func Debugf(format string, args ...any) {
	log.Printf("[DEBUG] "+format, args...)
}

type ctxLogger struct{}

// WithContext 兼容 logx.WithContext(ctx) 链式调用（忽略 context）。
func WithContext(context.Context) *ctxLogger {
	return &ctxLogger{}
}

func (l *ctxLogger) Infof(format string, args ...any)  { Infof(format, args...) }
func (l *ctxLogger) Errorf(format string, args ...any) { Errorf(format, args...) }
func (l *ctxLogger) Debugf(format string, args ...any) { Debugf(format, args...) }
func (l *ctxLogger) Info(args ...any)                  { Info(fmt.Sprint(args...)) }

func kv(keysAndValues ...any) string {
	if len(keysAndValues) == 0 {
		return ""
	}
	var b string
	for i := 0; i+1 < len(keysAndValues); i += 2 {
		b += " " + formatKV(keysAndValues[i], keysAndValues[i+1])
	}
	return b
}

func formatKV(k, v any) string {
	return fmt.Sprintf("%v=%v", k, v)
}
