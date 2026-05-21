// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package doc

import (
	"context"
	"net/http"

	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/core/logx"
)

type SwaggerUiLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewSwaggerUiLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SwaggerUiLogic {
	return &SwaggerUiLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *SwaggerUiLogic) SwaggerUi(w http.ResponseWriter) error {
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
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write([]byte(html))
	return nil
}
