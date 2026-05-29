package server

import (
	"encoding/json"
	"net/http"
	"strings"

	"backend/common/errorcode"

	"github.com/go-kratos/kratos/v2/encoding"
	"github.com/go-kratos/kratos/v2/errors"
	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
)

const envelopeOKMessage = "操作成功"

var envelopeSkipPrefixes = []string{
	"/health",
	"/migration",
	"/swagger",
	"/doc",
}

// EnvelopeResponseEncoder 将 proto HTTP 成功响应统一为：
// { "code": 200, "message": "...", "success": true, ...protoFields }
// 参考 core-platform 的 proto 直出 + moe 前端习惯的 code/message/success 信封。
func EnvelopeResponseEncoder(w http.ResponseWriter, r *http.Request, v any) error {
	if v == nil {
		return nil
	}
	if rd, ok := v.(khttp.Redirector); ok {
		url, code := rd.Redirect()
		http.Redirect(w, r, url, code)
		return nil
	}
	if shouldSkipEnvelope(r.URL.Path) {
		return khttp.DefaultResponseEncoder(w, r, v)
	}

	body, err := marshalEnvelopeSuccess(v)
	if err != nil {
		return err
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, err = w.Write(body)
	return err
}

// EnvelopeErrorEncoder 统一错误 JSON：
// { "code": <int>, "message": "...", "success": false, "reason": "..." }
func EnvelopeErrorEncoder(w http.ResponseWriter, r *http.Request, err error) {
	if err == nil {
		return
	}
	se := errors.FromError(err)
	httpStatus := mapErrorHTTPStatus(int(se.Code))

	body := map[string]any{
		"code":    int(se.Code),
		"message": se.Message,
		"success": false,
	}
	if reason := strings.TrimSpace(se.Reason); reason != "" {
		body["reason"] = reason
	}

	codec, _ := khttp.CodecForRequest(r, "Accept")
	if codec == nil {
		codec = encoding.GetCodec("json")
	}
	data, marshalErr := codec.Marshal(body)
	if marshalErr != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/"+codec.Name())
	w.WriteHeader(httpStatus)
	_, _ = w.Write(data)
}

func marshalEnvelopeSuccess(v any) ([]byte, error) {
	payload := make(map[string]any)
	switch msg := v.(type) {
	case proto.Message:
		b, err := protojson.Marshal(msg)
		if err != nil {
			return nil, err
		}
		if err := json.Unmarshal(b, &payload); err != nil {
			return nil, err
		}
	default:
		b, err := json.Marshal(v)
		if err != nil {
			return nil, err
		}
		if err := json.Unmarshal(b, &payload); err != nil {
			return nil, err
		}
	}

	out := make(map[string]any, len(payload)+3)
	for k, val := range payload {
		out[k] = val
	}
	if _, ok := out["code"]; !ok {
		out["code"] = errorcode.E_SUCCESS
	}
	if _, ok := out["success"]; !ok {
		out["success"] = true
	}
	if _, ok := out["message"]; !ok {
		out["message"] = envelopeOKMessage
	}
	return json.Marshal(out)
}

func shouldSkipEnvelope(path string) bool {
	for _, prefix := range envelopeSkipPrefixes {
		if path == prefix || strings.HasPrefix(path, prefix+"/") {
			return true
		}
	}
	return false
}

func mapErrorHTTPStatus(code int) int {
	switch {
	case code >= 100 && code < 600:
		return code
	case code >= 1000 && code < 10000:
		// 业务码（如 1001 用户不存在）保持 HTTP 200，与 compat 一致，由 success=false 表达。
		return http.StatusOK
	default:
		return http.StatusInternalServerError
	}
}
