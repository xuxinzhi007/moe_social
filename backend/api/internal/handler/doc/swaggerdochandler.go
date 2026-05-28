package doc

import (
	"net/http"
	"os"

	"backend/api/internal/svc"
)

func SwaggerDocHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		data, err := loadSwaggerJSON()
		if err != nil {
			http.Error(w, "swagger json not found", http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		_, _ = w.Write(data)
	}
}

func loadSwaggerJSON() ([]byte, error) {
	candidates := []string{
		"./rest.swagger.json",
		"../rest.swagger.json",
		"../../rest.swagger.json",
	}
	for _, p := range candidates {
		if b, err := os.ReadFile(p); err == nil {
			return b, nil
		}
	}
	return nil, os.ErrNotExist
}
