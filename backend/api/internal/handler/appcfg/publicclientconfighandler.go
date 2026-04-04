package appcfg

import (
	"encoding/json"
	"net/http"
	"strings"

	"backend/api/internal/svc"
)

type publicClientConfigResp struct {
	ApiBaseUrl string `json:"api_base_url"`
}

// PublicClientConfigHandler 无鉴权；内容由 backend/config/config.yaml 的 app_client.public_api_base_url 提供。
func PublicClientConfigHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		url := strings.TrimSpace(svcCtx.Config.AppClient.PublicApiBaseUrl)
		if url == "" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		for strings.HasSuffix(url, "/") {
			url = strings.TrimSuffix(url, "/")
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(w).Encode(publicClientConfigResp{ApiBaseUrl: url})
	}
}
