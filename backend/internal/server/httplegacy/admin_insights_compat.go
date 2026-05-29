package httplegacy

import (
	adminapp "backend/internal/service/admin"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterAdminInsightsCompat D2：已迁入 RegisterAdminInsightsHTTPServer。
func RegisterAdminInsightsCompat(srv *khttp.Server, app *adminapp.AppService) {
	_ = srv
	_ = app
}
