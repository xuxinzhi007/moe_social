package server

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

type flushRecorder struct {
	*httptest.ResponseRecorder
	flushed bool
}

func (r *flushRecorder) Flush() {
	r.flushed = true
}

func TestLoggingResponseWriterUnwrapsForResponseController(t *testing.T) {
	recorder := &flushRecorder{ResponseRecorder: httptest.NewRecorder()}
	writer := &loggingResponseWriter{ResponseWriter: recorder}

	if err := http.NewResponseController(writer).Flush(); err != nil {
		t.Fatalf("Flush() error = %v", err)
	}
	if !recorder.flushed {
		t.Fatal("Flush() did not reach the underlying response writer")
	}
}
