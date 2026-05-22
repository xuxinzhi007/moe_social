package runner

import (
	"fmt"
	"io"
	"sync"
)

// uploadProgressWriter reports SFTP upload progress to LogSink.
type uploadProgressWriter struct {
	sink     LogSink
	label    string
	total    int64
	written  int64
	lastPct  int
	mu       sync.Mutex
}

func newUploadProgressWriter(sink LogSink, label string, total int64) *uploadProgressWriter {
	return &uploadProgressWriter{sink: sink, label: label, total: total}
}

func (p *uploadProgressWriter) Write(b []byte) (int, error) {
	n := len(b)
	if n == 0 {
		return 0, nil
	}
	p.mu.Lock()
	p.written += int64(n)
	pct := 0
	if p.total > 0 {
		pct = int(p.written * 100 / p.total)
		if pct > 100 {
			pct = 100
		}
	}
	emit := p.sink != nil && (pct >= p.lastPct+2 || pct == 100 || p.lastPct < 0)
	if emit {
		p.lastPct = pct
		p.emitLocked(pct)
	}
	p.mu.Unlock()
	return n, nil
}

func (p *uploadProgressWriter) emitLocked(pct int) {
	human := fmt.Sprintf("  上传 %s: %d%% (%s / %s)\n",
		p.label, pct, formatUploadBytes(p.written), formatUploadBytes(p.total))
	p.sink(human)
	p.sink(fmt.Sprintf("UPLOAD_PROGRESS|%s|%d|%d|%d\n", p.label, pct, p.written, p.total))
}

func formatUploadBytes(n int64) string {
	const unit = 1024
	if n < unit {
		return fmt.Sprintf("%d B", n)
	}
	div, exp := int64(unit), 0
	for v := n / unit; v >= unit; v /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(n)/float64(div), "KMGTPE"[exp])
}

func copyUploadWithProgress(dst io.Writer, src io.Reader, sink LogSink, label string, total int64) (int64, error) {
	if sink != nil && total > 0 {
		sink(fmt.Sprintf("UPLOAD_PROGRESS|%s|0|0|%d\n", label, total))
	}
	pw := newUploadProgressWriter(sink, label, total)
	return io.Copy(dst, io.TeeReader(src, pw))
}
