package server

import (
	"bytes"
	"encoding/json"
	"net/http"
	"strings"
)

// compatEnvelopeFilter 将 httplegacy 的 BaseResp+data 响应压平为与 proto 信封一致的 JSON。
// 规则：保留 code/message/success；若 data 为 object 则合并到顶层；若为 array/scalar 则保留 data 字段。
func compatEnvelopeFilter(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if shouldSkipCompatEnvelope(r.URL.Path) {
			next.ServeHTTP(w, r)
			return
		}
		rec := &compatEnvelopeRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		if !rec.wroteHeader {
			return
		}
		if rec.status != http.StatusOK && rec.status != http.StatusCreated {
			if rec.buf.Len() > 0 {
				w.Header().Set("Content-Type", pickContentType(rec.header))
				w.WriteHeader(rec.status)
				_, _ = w.Write(rec.buf.Bytes())
			}
			return
		}
		body := bytes.TrimSpace(rec.buf.Bytes())
		if len(body) == 0 {
			w.WriteHeader(rec.status)
			return
		}
		ct := pickContentType(rec.header)
		if !strings.Contains(ct, "application/json") && !strings.Contains(ct, "json") {
			w.Header().Set("Content-Type", ct)
			w.WriteHeader(rec.status)
			_, _ = w.Write(body)
			return
		}
		flat, ok := flattenCompatJSON(body)
		if !ok {
			w.Header().Set("Content-Type", ct)
			w.WriteHeader(rec.status)
			_, _ = w.Write(body)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(rec.status)
		_, _ = w.Write(flat)
	})
}

func shouldSkipCompatEnvelope(path string) bool {
	for _, prefix := range envelopeSkipPrefixes {
		if path == prefix || strings.HasPrefix(path, prefix+"/") {
			return true
		}
	}
	// WebSocket 升级与静态资源不做 JSON 压平
	if strings.HasPrefix(path, "/ws") || strings.HasPrefix(path, "/api/ws") {
		return true
	}
	return false
}

func flattenCompatJSON(body []byte) ([]byte, bool) {
	var root map[string]any
	if err := json.Unmarshal(body, &root); err != nil {
		return nil, false
	}
	data, hasData := root["data"]
	if !hasData {
		return body, true
	}
	delete(root, "data")
	switch v := data.(type) {
	case map[string]any:
		for k, val := range v {
			if _, exists := root[k]; !exists {
				root[k] = val
			}
		}
	default:
		root["data"] = v
	}
	if _, ok := root["code"]; !ok {
		root["code"] = 200
	}
	if _, ok := root["success"]; !ok {
		root["success"] = true
	}
	if _, ok := root["message"]; !ok {
		root["message"] = envelopeOKMessage
	}
	out, err := json.Marshal(root)
	if err != nil {
		return nil, false
	}
	return out, true
}

func pickContentType(h http.Header) string {
	if ct := h.Get("Content-Type"); ct != "" {
		return ct
	}
	return "application/json"
}

type compatEnvelopeRecorder struct {
	http.ResponseWriter
	header      http.Header
	buf         bytes.Buffer
	status      int
	wroteHeader bool
}

func (r *compatEnvelopeRecorder) Header() http.Header {
	if r.header == nil {
		r.header = make(http.Header)
	}
	return r.header
}

func (r *compatEnvelopeRecorder) WriteHeader(statusCode int) {
	if r.wroteHeader {
		return
	}
	r.status = statusCode
	r.wroteHeader = true
}

func (r *compatEnvelopeRecorder) Write(b []byte) (int, error) {
	if !r.wroteHeader {
		r.WriteHeader(http.StatusOK)
	}
	return r.buf.Write(b)
}
