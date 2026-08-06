package doc

import (
	"net/http"
	"os"
	"strings"
)

func SwaggerDocHandler() http.HandlerFunc {
	return serveOpenAPISpec("application/json")
}

func SwaggerOpenAPIHandler() http.HandlerFunc {
	return serveOpenAPISpec("application/yaml")
}

func serveOpenAPISpec(contentType string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		data, err := loadOpenAPISpec()
		if err != nil {
			http.Error(w, "openapi spec not found", http.StatusNotFound)
			return
		}
		if strings.HasPrefix(contentType, "application/json") {
			w.Header().Set("Content-Type", "application/json; charset=utf-8")
		} else {
			w.Header().Set("Content-Type", "application/yaml; charset=utf-8")
		}
		_, _ = w.Write(data)
	}
}

func loadOpenAPISpec() ([]byte, error) {
	candidates := []string{
		"./openapi.yaml",
		"../openapi.yaml",
		"../../openapi.yaml",
	}
	for _, p := range candidates {
		if b, err := os.ReadFile(p); err == nil {
			return b, nil
		}
	}
	return nil, os.ErrNotExist
}
