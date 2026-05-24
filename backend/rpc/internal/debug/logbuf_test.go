package debug

import (
	"testing"
	"time"
)

func TestLogBufferAppendAndQuery(t *testing.T) {
	buf := NewLogBuffer(3)
	buf.Append(LogLevelInfo, "startup ok")
	buf.Append(LogLevelWarn, "slow query users")
	buf.Append(LogLevelError, "db connection failed")
	buf.Append(LogLevelInfo, "retry succeeded")

	all := buf.Query(LogQuery{Limit: 10})
	if all.Total != 3 {
		t.Fatalf("total=%d want 3", all.Total)
	}
	if all.Returned != 3 {
		t.Fatalf("returned=%d want 3", all.Returned)
	}
	if all.Entries[0].Message != "retry succeeded" {
		t.Fatalf("newest first: got %q", all.Entries[0].Message)
	}

	errOnly := buf.Query(LogQuery{Level: LogLevelError, Limit: 10})
	if errOnly.Returned != 1 || errOnly.Entries[0].Level != LogLevelError {
		t.Fatalf("error filter: %+v", errOnly)
	}

	search := buf.Query(LogQuery{Search: "slow", Limit: 10})
	if search.Returned != 1 || search.Entries[0].Level != LogLevelWarn {
		t.Fatalf("search filter: %+v", search)
	}
}

func TestLogBufferSinceFilter(t *testing.T) {
	buf := NewLogBuffer(10)
	buf.Append(LogLevelInfo, "old line")
	time.Sleep(5 * time.Millisecond)
	since := time.Now()
	time.Sleep(5 * time.Millisecond)
	buf.Append(LogLevelError, "new error")

	result := buf.Query(LogQuery{Since: since, Limit: 10})
	if result.Returned != 1 || result.Entries[0].Message != "new error" {
		t.Fatalf("since filter: %+v", result)
	}
}

func TestInferLevelFromText(t *testing.T) {
	cases := []struct {
		line string
		want LogLevel
	}{
		{"2026/05/24 12:00:00 rpc error: timeout", LogLevelError},
		{"2026-05-24T12:00:00+08:00\tslow\tusers/list", LogLevelWarn},
		{"2026-05-24T12:00:00+08:00\tinfo\tserver started", LogLevelInfo},
		{"RPC monitor stopped: connection refused", LogLevelInfo},
	}
	for _, tc := range cases {
		if got := inferLevelFromText(tc.line); got != tc.want {
			t.Fatalf("inferLevelFromText(%q)=%q want %q", tc.line, got, tc.want)
		}
	}
}

func TestNormalizeLevelFilter(t *testing.T) {
	if normalizeLevelFilter("err") != LogLevelError {
		t.Fatal("expected error alias")
	}
	if normalizeLevelFilter("all") != "" {
		t.Fatal("expected empty filter for all")
	}
}
