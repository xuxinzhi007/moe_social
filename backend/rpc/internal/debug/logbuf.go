package debug

import (
	"strings"
	"sync"
	"time"
)

// LogLevel classifies captured log lines for filtering in the monitor UI.
type LogLevel string

const (
	LogLevelError LogLevel = "error"
	LogLevelWarn  LogLevel = "warn"
	LogLevelInfo  LogLevel = "info"

	defaultLogCapacity = 2000
)

// LogEntry is one captured log line exposed via /debug/logs.
type LogEntry struct {
	ID        int64    `json:"id"`
	Timestamp string   `json:"timestamp"`
	Level     LogLevel `json:"level"`
	Message   string   `json:"message"`
}

// LogCounts summarizes entries currently held in the ring buffer.
type LogCounts struct {
	Total int `json:"total"`
	Error int `json:"error"`
	Warn  int `json:"warn"`
	Info  int `json:"info"`
}

// LogQuery holds filters for /debug/logs.
type LogQuery struct {
	Level      LogLevel
	Search     string
	Since      time.Time
	Limit      int
	CountsOnly bool
}

// LogQueryResult is the JSON body for /debug/logs.
type LogQueryResult struct {
	Timestamp string     `json:"timestamp"`
	Capacity  int        `json:"capacity"`
	Total     int        `json:"total"`
	Returned  int        `json:"returned"`
	Counts    LogCounts  `json:"counts"`
	Entries   []LogEntry `json:"entries,omitempty"`
}

// LogBuffer stores recent RPC logs in memory for local debugging only.
type LogBuffer struct {
	mu       sync.RWMutex
	capacity int
	entries  []LogEntry
	nextID   int64
}

var defaultLogBuffer = NewLogBuffer(defaultLogCapacity)

// NewLogBuffer creates a ring buffer that keeps at most capacity entries.
func NewLogBuffer(capacity int) *LogBuffer {
	if capacity <= 0 {
		capacity = defaultLogCapacity
	}
	return &LogBuffer{
		capacity: capacity,
		entries:  make([]LogEntry, 0, capacity),
	}
}

// Append stores one log line. Safe for concurrent use.
func (b *LogBuffer) Append(level LogLevel, message string) {
	message = strings.TrimSpace(message)
	if message == "" {
		return
	}
	if level == "" {
		level = LogLevelInfo
	}

	b.mu.Lock()
	defer b.mu.Unlock()

	b.nextID++
	entry := LogEntry{
		ID:        b.nextID,
		Timestamp: time.Now().Format(time.RFC3339Nano),
		Level:     level,
		Message:   message,
	}
	if len(b.entries) < b.capacity {
		b.entries = append(b.entries, entry)
		return
	}
	copy(b.entries, b.entries[1:])
	b.entries[len(b.entries)-1] = entry
}

// Query returns filtered entries, newest first.
func (b *LogBuffer) Query(q LogQuery) LogQueryResult {
	limit := q.Limit
	if limit <= 0 {
		limit = 100
	}
	if limit > 500 {
		limit = 500
	}

	b.mu.RLock()
	defer b.mu.RUnlock()

	counts := b.countsLocked()
	result := LogQueryResult{
		Timestamp: time.Now().Format(time.RFC3339),
		Capacity:  b.capacity,
		Total:     counts.Total,
		Counts:    counts,
	}
	if q.CountsOnly {
		return result
	}

	search := strings.ToLower(strings.TrimSpace(q.Search))
	levelFilter := normalizeLevelFilter(q.Level)
	hasSince := !q.Since.IsZero()

	matched := make([]LogEntry, 0, limit)
	for i := len(b.entries) - 1; i >= 0 && len(matched) < limit; i-- {
		entry := b.entries[i]
		if levelFilter != "" && entry.Level != levelFilter {
			continue
		}
		if hasSince {
			ts, err := time.Parse(time.RFC3339Nano, entry.Timestamp)
			if err != nil || ts.Before(q.Since) {
				continue
			}
		}
		if search != "" && !strings.Contains(strings.ToLower(entry.Message), search) {
			continue
		}
		matched = append(matched, entry)
	}

	result.Returned = len(matched)
	result.Entries = matched
	return result
}

func (b *LogBuffer) countsLocked() LogCounts {
	counts := LogCounts{Total: len(b.entries)}
	for _, entry := range b.entries {
		switch entry.Level {
		case LogLevelError:
			counts.Error++
		case LogLevelWarn:
			counts.Warn++
		default:
			counts.Info++
		}
	}
	return counts
}

func normalizeLevelFilter(level LogLevel) LogLevel {
	switch strings.ToLower(string(level)) {
	case "error", "err", "errors":
		return LogLevelError
	case "warn", "warning", "warnings":
		return LogLevelWarn
	case "info", "information":
		return LogLevelInfo
	case "all", "":
		return ""
	default:
		return level
	}
}

// inferLevelFromText guesses severity from plain-text log lines (stdlib log).
func inferLevelFromText(line string) LogLevel {
	lower := strings.ToLower(line)
	switch {
	case strings.Contains(lower, "\terror\t"),
		strings.Contains(lower, "\tsevere\t"),
		strings.Contains(lower, "\tstack\t"),
		strings.Contains(lower, "\talert\t"):
		return LogLevelError
	case strings.Contains(lower, "\tslow\t"):
		return LogLevelWarn
	case strings.Contains(lower, " error:"),
		strings.Contains(lower, " failed"),
		strings.Contains(lower, "失败"),
		strings.Contains(lower, "panic"):
		return LogLevelError
	case strings.Contains(lower, " warn"),
		strings.Contains(lower, "warning"):
		return LogLevelWarn
	default:
		return LogLevelInfo
	}
}
