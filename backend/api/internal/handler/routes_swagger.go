package handler

import (
	"net/http"
	"os"

	"github.com/zeromicro/go-zero/rest"
)

// RegisterSwaggerRoutes 提供本地 Swagger 文档访问：
// - GET /swagger          Swagger UI
// - GET /swagger/         Swagger UI
// - GET /swagger/doc.json OpenAPI/Swagger JSON
func RegisterSwaggerRoutes(server *rest.Server) {
	server.AddRoutes([]rest.Route{
		{
			Method:  http.MethodGet,
			Path:    "/swagger",
			Handler: swaggerUIHandler(),
		},
		{
			Method:  http.MethodGet,
			Path:    "/swagger/doc.json",
			Handler: swaggerJSONHandler(),
		},
	})
}

func swaggerUIHandler() http.HandlerFunc {
	const html = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Moe Social API Docs</title>
    <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
    <style>
      body { margin: 0; background: #fafafa; }
      #swagger-ui { max-width: 1200px; margin: 0 auto; }
    </style>
  </head>
  <body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
    <script>
      window.ui = SwaggerUIBundle({
        url: '/swagger/doc.json',
        dom_id: '#swagger-ui',
        deepLinking: true,
        defaultModelsExpandDepth: 1,
        displayRequestDuration: true,
      });
    </script>
  </body>
</html>`
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write([]byte(html))
	}
}

func swaggerJSONHandler() http.HandlerFunc {
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
	// 常见启动路径：
	// 1) cd backend/api && go run super.go ...
	// 2) cd backend && go run api/super.go ...
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
