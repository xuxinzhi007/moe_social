package httplegacy

import (
	adminapp "backend/internal/service/admin"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeAdminReadonlyCompatRoutes PK-3：已迁入 RegisterAdminInsightsHTTPServer。
const PilotNativeAdminReadonlyCompatRoutes = 0

// RegisterAdminReadonlyCompat Admin 只读 HTTP（dashboard / growth / schema）已迁入 proto HTTP。
func RegisterAdminReadonlyCompat(srv *khttp.Server, app *adminapp.AppService) {
	_ = srv
	_ = app
}
