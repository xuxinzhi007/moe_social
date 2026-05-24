// Package debug exposes a local-only HTTP monitor for RPC performance inspection.
package debug

import (
	"backend/devports"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"log"
	"net"
	"net/http"
	_ "net/http/pprof" // registers /debug/pprof/* on DefaultServeMux
	"os"
	"runtime"
	"runtime/pprof"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/google/pprof/profile"
)

const defaultDebugAddr = devports.RpcDebugAddr

var monitorBaseURL = "http://" + defaultDebugAddr

// Monitor serves local-only pprof and JSON stats inside the RPC process.
// Call Stop when the RPC process exits. Use only with super.go -debug or make rpc-debug.
type Monitor struct {
	server *http.Server
}

// StartMonitor listens on preferredAddr (default devports.RpcDebugAddr) for pprof and JSON stats.
// Uses Moe reserved block 19011–19016 if busy.
// Set MOE_RPC_DEBUG_ADDR to override. Bind to loopback only; do not expose publicly.
func StartMonitor(preferredAddr string) *Monitor {
	if env := strings.TrimSpace(os.Getenv("MOE_RPC_DEBUG_ADDR")); env != "" {
		preferredAddr = env
	}
	if strings.TrimSpace(preferredAddr) == "" {
		preferredAddr = defaultDebugAddr
	}

	ln, addr, err := listenMonitor(preferredAddr)
	if err != nil {
		log.Printf("RPC monitor disabled: %v", err)
		return nil
	}

	monitorBaseURL = "http://" + addr

	InstallLogCapture()

	http.HandleFunc("/debug/live", handleLive)
	http.HandleFunc("/debug/heap-top", handleHeapTop)
	http.HandleFunc("/debug/goroutine-summary", handleGoroutineSummary)
	http.HandleFunc("/debug/logs", handleLogs)

	srv := &http.Server{
		Handler: withCORS(http.DefaultServeMux),
	}

	go func() {
		log.Printf("RPC debug API: http://%s/debug/live (dashboard: make rpc-monitor)", addr)
		if err := srv.Serve(ln); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Printf("RPC monitor stopped: %v", err)
		}
	}()

	return &Monitor{server: srv}
}

// Stop shuts down the monitor HTTP server. Safe to call on nil or after Stop.
func (m *Monitor) Stop() {
	if m == nil || m.server == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := m.server.Shutdown(ctx); err != nil {
		log.Printf("RPC monitor shutdown: %v", err)
	}
}

func listenMonitor(preferred string) (net.Listener, string, error) {
	host, portStr, err := net.SplitHostPort(preferred)
	if err != nil {
		return nil, "", err
	}
	port, err := strconv.Atoi(portStr)
	if err != nil || port <= 0 {
		return nil, "", err
	}

	seen := map[int]struct{}{port: {}}
	candidates := []int{port}
	for _, p := range devports.RpcDebugFallbackPorts() {
		if _, ok := seen[p]; ok {
			continue
		}
		seen[p] = struct{}{}
		candidates = append(candidates, p)
	}

	var lastErr error
	for _, p := range candidates {
		addr := net.JoinHostPort(host, strconv.Itoa(p))
		ln, err := net.Listen("tcp", addr)
		if err != nil {
			lastErr = err
			continue
		}
		if p != port {
			log.Printf("RPC monitor: %s busy (%v), using %s instead", preferred, lastErr, addr)
		}
		return ln, addr, nil
	}
	return nil, "", lastErr
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	if err := enc.Encode(v); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

func handleLive(w http.ResponseWriter, _ *http.Request) {
	var ms runtime.MemStats
	runtime.ReadMemStats(&ms)

	writeJSON(w, map[string]any{
		"timestamp":  time.Now().Format(time.RFC3339),
		"goroutines": runtime.NumGoroutine(),
		"memory": map[string]any{
			"alloc_mb":       bytesToMB(ms.Alloc),
			"total_alloc_mb": bytesToMB(ms.TotalAlloc),
			"sys_mb":         bytesToMB(ms.Sys),
			"heap_alloc_mb":  bytesToMB(ms.HeapAlloc),
			"heap_sys_mb":    bytesToMB(ms.HeapSys),
			"heap_inuse_mb":  bytesToMB(ms.HeapInuse),
			"heap_idle_mb":   bytesToMB(ms.HeapIdle),
			"stack_inuse_mb": bytesToMB(ms.StackInuse),
		},
		"gc": map[string]any{
			"num_gc":          ms.NumGC,
			"pause_total_ms":  float64(ms.PauseTotalNs) / 1e6,
			"last_pause_ms":   float64(ms.PauseNs[(ms.NumGC+255)%256]) / 1e6,
			"gc_cpu_fraction": ms.GCCPUFraction,
		},
		"links": pprofLinks(),
	})
}

type heapEntry struct {
	Function string  `json:"function"`
	File     string  `json:"file,omitempty"`
	InuseMB  float64 `json:"inuse_mb"`
	Objects  int64   `json:"objects"`
}

func handleHeapTop(w http.ResponseWriter, r *http.Request) {
	limit := 15
	if q := r.URL.Query().Get("limit"); q != "" {
		if n, err := strconv.Atoi(q); err == nil && n > 0 && n <= 50 {
			limit = n
		}
	}

	entries, err := topHeapAllocators(limit)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]any{
		"timestamp": time.Now().Format(time.RFC3339),
		"unit":      "inuse_heap_bytes",
		"top":       entries,
		"hint":      "关注 inuse_mb 持续偏高的函数；配合 go tool pprof 做火焰图",
	})
}

func handleLogs(w http.ResponseWriter, r *http.Request) {
	q := LogQuery{
		Level:      LogLevel(strings.TrimSpace(r.URL.Query().Get("level"))),
		Search:     strings.TrimSpace(r.URL.Query().Get("q")),
		CountsOnly: strings.EqualFold(strings.TrimSpace(r.URL.Query().Get("counts_only")), "1") ||
			strings.EqualFold(strings.TrimSpace(r.URL.Query().Get("counts_only")), "true"),
	}
	if raw := strings.TrimSpace(r.URL.Query().Get("limit")); raw != "" {
		if n, err := strconv.Atoi(raw); err == nil && n > 0 {
			q.Limit = n
		}
	}
	if raw := strings.TrimSpace(r.URL.Query().Get("since")); raw != "" {
		if ts, err := time.Parse(time.RFC3339, raw); err == nil {
			q.Since = ts
		}
	}

	writeJSON(w, defaultLogBuffer.Query(q))
}

func handleGoroutineSummary(w http.ResponseWriter, _ *http.Request) {
	count := runtime.NumGoroutine()
	stacks, err := sampleGoroutineStacks(8)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]any{
		"timestamp":  time.Now().Format(time.RFC3339),
		"goroutines": count,
		"sample_top": stacks,
		"hint":       "goroutines 持续飙升可能泄漏；用 go tool pprof goroutine 看完整栈",
	})
}

func topHeapAllocators(limit int) ([]heapEntry, error) {
	var buf bytes.Buffer
	if err := pprof.WriteHeapProfile(&buf); err != nil {
		return nil, err
	}
	prof, err := profile.Parse(&buf)
	if err != nil {
		return nil, err
	}

	type agg struct {
		name    string
		file    string
		inuse   int64
		objects int64
	}
	byFunc := map[string]*agg{}

	for _, s := range prof.Sample {
		var inuse, objects int64
		for i, label := range prof.SampleType {
			if i >= len(s.Value) {
				continue
			}
			switch label.Type {
			case "inuse_space":
				inuse = s.Value[i]
			case "inuse_objects":
				objects = s.Value[i]
			}
		}
		if inuse <= 0 {
			continue
		}

		fn := "unknown"
		file := ""
		if len(s.Location) > 0 && len(s.Location[0].Line) > 0 {
			line := s.Location[0].Line[0]
			if line.Function != nil {
				fn = line.Function.Name
				file = line.Function.Filename
			}
		}
		key := fn
		if byFunc[key] == nil {
			byFunc[key] = &agg{name: fn, file: file}
		}
		byFunc[key].inuse += inuse
		byFunc[key].objects += objects
	}

	list := make([]*agg, 0, len(byFunc))
	for _, a := range byFunc {
		list = append(list, a)
	}
	sort.Slice(list, func(i, j int) bool { return list[i].inuse > list[j].inuse })

	if limit > len(list) {
		limit = len(list)
	}
	out := make([]heapEntry, 0, limit)
	for i := 0; i < limit; i++ {
		a := list[i]
		out = append(out, heapEntry{
			Function: trimRuntimePrefix(a.name),
			File:     a.file,
			InuseMB:  bytesToMB(uint64(a.inuse)),
			Objects:  a.objects,
		})
	}
	return out, nil
}

func sampleGoroutineStacks(limit int) ([]map[string]any, error) {
	var buf bytes.Buffer
	if err := pprof.Lookup("goroutine").WriteTo(&buf, 2); err != nil {
		return nil, err
	}

	type key struct {
		top string
	}
	counts := map[key]int{}
	lines := strings.Split(buf.String(), "\n")
	var cur []string
	flush := func() {
		if len(cur) == 0 {
			return
		}
		top := ""
		for _, ln := range cur {
			ln = strings.TrimSpace(ln)
			if strings.HasPrefix(ln, "#") && top == "" {
				top = strings.TrimSpace(strings.TrimPrefix(ln, "#"))
				break
			}
		}
		if top != "" {
			counts[key{top: top}]++
		}
		cur = nil
	}

	for _, ln := range lines {
		if strings.HasPrefix(ln, "goroutine ") {
			flush()
		}
		if strings.HasPrefix(ln, "#") {
			cur = append(cur, ln)
		}
	}
	flush()

	type item struct {
		stack string
		n     int
	}
	items := make([]item, 0, len(counts))
	for k, n := range counts {
		items = append(items, item{stack: k.top, n: n})
	}
	sort.Slice(items, func(i, j int) bool { return items[i].n > items[j].n })
	if limit > len(items) {
		limit = len(items)
	}

	out := make([]map[string]any, 0, limit)
	for i := 0; i < limit; i++ {
		out = append(out, map[string]any{
			"count": items[i].n,
			"stack": items[i].stack,
		})
	}
	return out, nil
}

func bytesToMB(b uint64) float64 {
	return float64(b) / (1024 * 1024)
}

func trimRuntimePrefix(fn string) string {
	fn = strings.TrimPrefix(fn, "github.com/zeromicro/go-zero/")
	return fn
}

func pprofLinks() map[string]string {
	base := monitorBaseURL
	return map[string]string{
		"pprof_index": base + "/debug/pprof/",
		"heap":        base + "/debug/pprof/heap",
		"goroutine":   base + "/debug/pprof/goroutine",
		"profile_30s": base + "/debug/pprof/profile?seconds=30",
	}
}
