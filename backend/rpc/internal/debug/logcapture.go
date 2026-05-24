package debug

import (
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"sync"

	"github.com/zeromicro/go-zero/core/logx"
)

var installCaptureOnce sync.Once

// InstallLogCapture hooks logx and stdlib log output into the in-memory buffer.
// Safe to call multiple times; only the first call takes effect.
func InstallLogCapture() {
	installCaptureOnce.Do(func() {
		prev := logx.Reset()
		if prev == nil {
			prev = logx.NewWriter(os.Stderr)
		}
		logx.SetWriter(&captureWriter{inner: prev})

		log.SetOutput(&stdLogCapture{dst: os.Stderr})
	})
}

type captureWriter struct {
	inner logx.Writer
}

func (w *captureWriter) Alert(v any) {
	defaultLogBuffer.Append(LogLevelError, formatLogMessage("alert", v))
	w.inner.Alert(v)
}

func (w *captureWriter) Close() error {
	return w.inner.Close()
}

func (w *captureWriter) Debug(v any, fields ...logx.LogField) {
	defaultLogBuffer.Append(LogLevelInfo, formatLogMessage("debug", v, fields...))
	w.inner.Debug(v, fields...)
}

func (w *captureWriter) Error(v any, fields ...logx.LogField) {
	defaultLogBuffer.Append(LogLevelError, formatLogMessage("error", v, fields...))
	w.inner.Error(v, fields...)
}

func (w *captureWriter) Info(v any, fields ...logx.LogField) {
	defaultLogBuffer.Append(LogLevelInfo, formatLogMessage("info", v, fields...))
	w.inner.Info(v, fields...)
}

func (w *captureWriter) Severe(v any) {
	defaultLogBuffer.Append(LogLevelError, formatLogMessage("severe", v))
	w.inner.Severe(v)
}

func (w *captureWriter) Slow(v any, fields ...logx.LogField) {
	defaultLogBuffer.Append(LogLevelWarn, formatLogMessage("slow", v, fields...))
	w.inner.Slow(v, fields...)
}

func (w *captureWriter) Stack(v any) {
	defaultLogBuffer.Append(LogLevelError, formatLogMessage("stack", v))
	w.inner.Stack(v)
}

func (w *captureWriter) Stat(v any, fields ...logx.LogField) {
	defaultLogBuffer.Append(LogLevelInfo, formatLogMessage("stat", v, fields...))
	w.inner.Stat(v, fields...)
}

type stdLogCapture struct {
	dst io.Writer
}

func (w *stdLogCapture) Write(p []byte) (int, error) {
	text := strings.TrimSpace(string(p))
	if text != "" {
		for _, line := range strings.Split(text, "\n") {
			line = strings.TrimSpace(line)
			if line == "" {
				continue
			}
			defaultLogBuffer.Append(inferLevelFromText(line), line)
		}
	}
	return w.dst.Write(p)
}

func formatLogMessage(level string, v any, fields ...logx.LogField) string {
	msg := fmt.Sprint(v)
	if len(fields) > 0 {
		parts := make([]string, 0, len(fields))
		for _, field := range fields {
			parts = append(parts, fmt.Sprintf("%s=%v", field.Key, field.Value))
		}
		msg = msg + " " + strings.Join(parts, " ")
	}
	return level + " " + msg
}
