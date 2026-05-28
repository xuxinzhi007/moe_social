package admingw

import (
	adminapp "backend/internal/service/admin"
	"backend/internal/platform/moewiring"
	"backend/rpc/pb/super"
)

// NewConfigured 按 config.yaml 构造网关（PK-2/3 kratos_http 灰度）。
func NewConfigured(local *adminapp.AppService, legacy super.SuperClient) *Gateway {
	var kratos *KratosHTTPClient
	if moewiring.KratosAdminInsightsHTTPEnabled() {
		kratos = NewKratosHTTPClient(moewiring.KratosPilotBaseURL())
	}
	return New(local, legacy, kratos)
}
