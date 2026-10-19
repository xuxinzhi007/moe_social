package moelog

import (
	"bytes"
	"context"
	"errors"
	"log"
	"os"
	"strings"
	"testing"
	"time"

	"gorm.io/gorm"
)

func TestGORMTraceKeepsSQLAndDropsNotFoundLabel(t *testing.T) {
	var buf bytes.Buffer
	log.SetOutput(&buf)
	t.Cleanup(func() { log.SetOutput(os.Stderr) })

	GORMLogger().Trace(context.Background(), time.Now(), func() (string, int64) {
		return "SELECT 1", 0
	}, gorm.ErrRecordNotFound)

	got := buf.String()
	if strings.Contains(got, "record not found") {
		t.Fatalf("not-found labeled as failure: %s", got)
	}
	if !strings.Contains(got, "[DEBUG]") || !strings.Contains(got, "SELECT 1") {
		t.Fatalf("sql debug missing: %s", got)
	}
}

func TestGORMTraceLogsRealErrors(t *testing.T) {
	var buf bytes.Buffer
	log.SetOutput(&buf)
	t.Cleanup(func() { log.SetOutput(os.Stderr) })

	GORMLogger().Trace(context.Background(), time.Now(), func() (string, int64) {
		return "SELECT 1", 0
	}, errors.New("connection reset"))

	got := buf.String()
	if !strings.Contains(got, "[ERROR]") || !strings.Contains(got, "connection reset") {
		t.Fatalf("sql error missing: %s", got)
	}
}
