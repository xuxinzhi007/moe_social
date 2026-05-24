package handler



import (

	"bytes"

	"io"

	"net/http"

	"net/url"

	"strings"

	"time"

)



func (h *Handler) adminLoginProxy(w http.ResponseWriter, r *http.Request) {

	if r.Method != http.MethodPost {

		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)

		return

	}

	h.forwardToAPI(w, r, "/api/admin/login")

}



func (h *Handler) adminAPIProxy(w http.ResponseWriter, r *http.Request) {

	suffix := strings.TrimPrefix(r.URL.Path, "/api/deploy/admin")

	if suffix == "" {

		suffix = "/"

	}

	h.forwardToAPI(w, r, "/api/admin"+suffix)

}



func (h *Handler) adminDashboardProxy(w http.ResponseWriter, r *http.Request) {

	h.forwardToAPI(w, r, "/api/admin/dashboard")

}



func (h *Handler) forwardToAPI(w http.ResponseWriter, r *http.Request, apiPath string) {

	targetID := strings.TrimSpace(r.URL.Query().Get("target"))

	if targetID == "" {

		targetID = h.Cfg.DefaultTarget()

	}

	target := h.Cfg.TargetByID(targetID)

	apiBase := strings.TrimSpace(target.APIBaseURL)

	if apiBase == "" {

		apiBase = "http://127.0.0.1:8888"

	}



	upstream, err := url.Parse(apiBase)

	if err != nil {

		writeJSON(w, http.StatusBadRequest, map[string]any{

			"success": false,

			"message": "无效的 api_base_url",

		})

		return

	}

	upstream.Path = apiPath



	q := r.URL.Query()

	q.Del("target")

	upstream.RawQuery = q.Encode()



	var body io.Reader

	if r.Body != nil && r.Method != http.MethodGet && r.Method != http.MethodHead {

		raw, readErr := io.ReadAll(io.LimitReader(r.Body, 4<<20))

		if readErr != nil {

			writeJSON(w, http.StatusBadRequest, map[string]any{"success": false, "message": readErr.Error()})

			return

		}

		body = bytes.NewReader(raw)

	}



	req, err := http.NewRequestWithContext(r.Context(), r.Method, upstream.String(), body)

	if err != nil {

		writeJSON(w, http.StatusInternalServerError, map[string]any{"success": false, "message": err.Error()})

		return

	}



	if ct := r.Header.Get("Content-Type"); ct != "" {

		req.Header.Set("Content-Type", ct)

	}

	if token := strings.TrimSpace(r.Header.Get("X-Admin-Token")); token != "" {

		req.Header.Set("X-Admin-Token", token)

	}



	client := &http.Client{Timeout: 30 * time.Second}

	resp, err := client.Do(req)

	if err != nil {

		writeJSON(w, http.StatusBadGateway, map[string]any{

			"success": false,

			"message": "无法连接 API: " + err.Error(),

		})

		return

	}

	defer resp.Body.Close()



	respBody, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))

	if err != nil {

		writeJSON(w, http.StatusBadGateway, map[string]any{"success": false, "message": err.Error()})

		return

	}



	for k, vals := range resp.Header {

		if strings.EqualFold(k, "Content-Type") {

			for _, v := range vals {

				w.Header().Add(k, v)

			}

		}

	}

	w.WriteHeader(resp.StatusCode)

	_, _ = w.Write(respBody)

}



func (h *Handler) platformHealth(w http.ResponseWriter, r *http.Request) {

	if r.Method != http.MethodGet {

		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)

		return

	}



	local := h.probeAPIHealth("local")

	cloud := h.probeAPIHealth("cloud")



	writeJSON(w, http.StatusOK, map[string]any{

		"success":        true,

		"agent":          map[string]any{"online": true, "listen": h.Cfg.Listen},

		"local_api":      local,

		"cloud_api":      cloud,

		"default_target": h.Cfg.DefaultTarget(),

	})

}



func (h *Handler) probeAPIHealth(targetID string) map[string]any {

	target := h.Cfg.TargetByID(targetID)

	apiBase := strings.TrimSpace(target.APIBaseURL)

	if apiBase == "" {

		apiBase = "http://127.0.0.1:8888"

	}

	out := map[string]any{

		"target":   targetID,

		"base_url": apiBase,

		"online":   false,

	}

	u, err := url.Parse(apiBase)

	if err != nil {

		out["message"] = "无效的 api_base_url"

		return out

	}

	u.Path = "/api/ops/landing/feedback"

	q := u.Query()

	q.Set("page", "1")

	q.Set("page_size", "1")

	u.RawQuery = q.Encode()



	req, err := http.NewRequest(http.MethodGet, u.String(), nil)

	if err != nil {

		out["message"] = err.Error()

		return out

	}

	client := &http.Client{Timeout: 4 * time.Second}

	resp, err := client.Do(req)

	if err != nil {

		out["message"] = err.Error()

		return out

	}

	defer resp.Body.Close()

	out["status_code"] = resp.StatusCode

	if resp.StatusCode == http.StatusOK {

		out["online"] = true

		out["message"] = "ok"

		return out

	}

	out["message"] = resp.Status

	return out

}


