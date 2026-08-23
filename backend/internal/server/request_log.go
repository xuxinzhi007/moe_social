package server

import (
	"bufio"
	"log"
	"net"
	"net/http"
	"time"
)

type loggingResponseWriter struct {
	http.ResponseWriter
	status int
}

func (w *loggingResponseWriter) WriteHeader(status int) {
	w.status = status
	w.ResponseWriter.WriteHeader(status)
}

// Unwrap exposes the underlying writer so ResponseController can flush SSE
// responses through this logging wrapper.
func (w *loggingResponseWriter) Unwrap() http.ResponseWriter {
	return w.ResponseWriter
}

// Hijack 让 loggingResponseWriter 满足 http.Hijacker 接口，
// 使 gorilla/websocket.Upgrader 能正常升级 WebSocket 连接。
func (w *loggingResponseWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	if hj, ok := w.ResponseWriter.(http.Hijacker); ok {
		return hj.Hijack()
	}
	return nil, nil, http.ErrNotSupported
}

func requestLogFilter(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		lrw := &loggingResponseWriter{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(lrw, r)
		log.Printf("[HTTP] method=%s path=%s status=%d duration=%s", r.Method, r.URL.Path, lrw.status, time.Since(start).Round(time.Millisecond))
	})
}
