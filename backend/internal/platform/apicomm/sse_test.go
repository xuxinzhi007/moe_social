package apicomm

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

type unwrappingResponseWriter struct {
	http.ResponseWriter
}

func (w unwrappingResponseWriter) Unwrap() http.ResponseWriter {
	return w.ResponseWriter
}

type flushingRecorder struct {
	*httptest.ResponseRecorder
	flushed bool
}

func (r *flushingRecorder) Flush() {
	r.flushed = true
}

func TestWriteSSEFlushesUnwrappedResponseWriter(t *testing.T) {
	recorder := &flushingRecorder{ResponseRecorder: httptest.NewRecorder()}
	writer := unwrappingResponseWriter{ResponseWriter: recorder}

	if err := WriteSSE(writer, "done", map[string]string{"text": "ok"}); err != nil {
		t.Fatalf("WriteSSE() error = %v", err)
	}
	if !recorder.flushed {
		t.Fatal("WriteSSE() did not flush the unwrapped response writer")
	}
	if got, want := recorder.Body.String(), "event: done\ndata: {\"text\":\"ok\"}\n\n"; got != want {
		t.Fatalf("WriteSSE() body = %q, want %q", got, want)
	}
}
